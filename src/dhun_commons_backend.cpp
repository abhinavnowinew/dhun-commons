#include "dhun_commons_backend.h"

#include "logos_sdk.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
#include <QHash>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <QTimer>
#include <QUrl>
#include <QUrlQuery>

#include <cmath>

namespace {

const char kSequencer[] = "https://testnet.lez.logos.co";
const char kWalletSubdir[] = "dhun_chain";
const char kRelaySubdir[] = "Logos/LogosBasecamp/dhun_relay";
const char kConfigName[] = "config.json";
const char kStorageName[] = "storage.json";
const char kMappingName[] = "roles.json";
const char kTokenDecimals = 9;
const int kMaxTelegramSnapshot = 256 * 1024;
const char kOpenRouterUrl[] = "https://openrouter.ai/api/v1/chat/completions";
const char kOpenRouterDefaultModel[] = "openai/gpt-4o";
const int kMaxAiMessages = 40;
const int kMaxAiPromptChars = 24000;
const char kXeniaRoomDefault[] = "agora";
const int kXeniaPollMs = 1200;
const int kXeniaWaitMs = 100000;
const int kMaxXeniaPromptChars = 12000;
const int kMaxSignalAnswerChars = 4000;
const int kMaxTextFileBytes = 256 * 1024;
const int kMaxTextChars = 120000;
const char kOpenMeteoUrl[] = "https://api.open-meteo.com/v1/forecast";
const char kAgroDailyVars[] =
    "weather_code,temperature_2m_max,temperature_2m_min,"
    "apparent_temperature_max,apparent_temperature_min,"
    "precipitation_sum,precipitation_probability_max,"
    "wind_speed_10m_max,wind_gusts_10m_max,wind_direction_10m_dominant,"
    "relative_humidity_2m_mean,et0_fao_evapotranspiration,"
    "shortwave_radiation_sum,uv_index_max,"
    "soil_moisture_0_to_10cm_mean,dew_point_2m_mean,cloud_cover_mean";
const char kAgroCurrentVars[] =
    "temperature_2m,relative_humidity_2m,precipitation,weather_code,"
    "wind_speed_10m,wind_gusts_10m,wind_direction_10m,"
    "soil_moisture_0_to_10cm,soil_temperature_6cm";
const qint64 kAgroCacheMs = 30 * 60 * 1000;

struct Role {
    const char* key;
    const char* name;
};

struct AgroCacheEntry {
    qint64 savedAt = 0;
    QJsonObject payload;
};

const Role kRoles[] = {
    {"funder", "Funder"},
    {"dhun", "Dhun"},
    {"steward", "Steward"},
};

QString jsonCompact(const QJsonObject& obj)
{
    return QString::fromUtf8(QJsonDocument(obj).toJson(QJsonDocument::Compact));
}

QJsonObject failureObject(const QString& error)
{
    QJsonObject obj;
    obj.insert(QStringLiteral("success"), false);
    obj.insert(QStringLiteral("error"), error);
    return obj;
}

void insertNumber(QJsonObject& obj, const char* key, double value)
{
    obj.insert(QString::fromLatin1(key),
               std::isfinite(value) ? QJsonValue(value) : QJsonValue(QJsonValue::Null));
}

double seriesValue(const QJsonObject& series, const char* key, int index)
{
    const QJsonArray values = series.value(QString::fromLatin1(key)).toArray();
    if (index < 0 || index >= values.size())
        return qQNaN();
    const QJsonValue value = values.at(index);
    if (value.isNull() || value.isUndefined())
        return qQNaN();
    return value.toDouble(qQNaN());
}

QString redactSecret(QString text, const QString& secret)
{
    if (secret.size() >= 8 && text.contains(secret))
        text.replace(secret, QStringLiteral("[redacted]"));
    return text;
}

bool isHexAccountId(const QString& value)
{
    static const QRegularExpression re(QStringLiteral("^[0-9a-fA-F]{64}$"));
    return re.match(value.trimmed()).hasMatch();
}

QString normaliseAccountId(const QString& value)
{
    return value.trimmed().toLower();
}

QString leptaToToken(QString lepta)
{
    lepta = lepta.trimmed();
    if (lepta.isEmpty())
        return QString();
    for (const QChar c : lepta) {
        if (!c.isDigit())
            return QString();
    }
    while (lepta.size() > 1 && lepta.startsWith(QLatin1Char('0')))
        lepta.remove(0, 1);
    if (lepta == QLatin1String("0"))
        return QStringLiteral("0");

    if (lepta.size() <= kTokenDecimals) {
        QString fraction = lepta;
        while (fraction.size() < kTokenDecimals)
            fraction.prepend(QLatin1Char('0'));
        fraction.remove(QRegularExpression(QStringLiteral("0+$")));
        return fraction.isEmpty() ? QStringLiteral("0") : QStringLiteral("0.") + fraction;
    }

    const int wholeLength = lepta.size() - kTokenDecimals;
    QString whole = lepta.left(wholeLength);
    QString fraction = lepta.mid(wholeLength);
    while (fraction.endsWith(QLatin1Char('0')))
        fraction.chop(1);
    return fraction.isEmpty() ? whole : whole + QLatin1Char('.') + fraction;
}

QString tokenToLe16Hex(const QString& amount, QString* error)
{
    const QString trimmed = amount.trimmed();
    static const QRegularExpression re(QStringLiteral("^(\\d{1,30})(?:\\.(\\d{1,9}))?$"));
    const QRegularExpressionMatch match = re.match(trimmed);
    if (!match.hasMatch()) {
        if (error)
            *error = QStringLiteral("Enter an amount in LEZ with at most 9 decimal places.");
        return QString();
    }

    const QString whole = match.captured(1);
    QString fraction = match.captured(2);
    if (whole == QLatin1String("0") && (fraction.isEmpty() || fraction.count(QLatin1Char('0')) == fraction.size())) {
        if (error)
            *error = QStringLiteral("The settlement amount must be greater than zero.");
        return QString();
    }

    while (fraction.size() < kTokenDecimals)
        fraction.append(QLatin1Char('0'));

    const QString decimal = whole + fraction;
    const unsigned __int128 maximum = ~static_cast<unsigned __int128>(0);
    unsigned __int128 value = 0;
    for (const QChar c : decimal) {
        const unsigned __int128 digit = static_cast<unsigned>(c.digitValue());
        if (value > (maximum - digit) / 10) {
            if (error)
                *error = QStringLiteral("That amount is too large for a LEZ transfer.");
            return QString();
        }
        value = value * 10 + digit;
    }
    if (value == 0) {
        if (error)
            *error = QStringLiteral("The settlement amount must be greater than zero.");
        return QString();
    }

    QByteArray raw(16, '\0');
    for (int i = 0; i < 16; ++i)
        raw[i] = static_cast<char>((value >> (i * 8)) & 0xff);
    return QString::fromLatin1(raw.toHex());
}

} // namespace

QString DhunCommonsBackend::baseWalletDirectory()
{
    if (m_contextReady) {
        const QString fromModule = modules().lez_core.wallet_dir();
        if (!fromModule.isEmpty() && fromModule != QLatin1String("-"))
            return fromModule;
    }
    QString fallback = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    if (fallback.isEmpty())
        fallback = QDir::homePath() + QStringLiteral("/.dhun_commons");
    return fallback;
}

QString DhunCommonsBackend::walletDirectory()
{
    return QDir(baseWalletDirectory()).filePath(QString::fromLatin1(kWalletSubdir));
}

QString DhunCommonsBackend::telegramDirectory() const
{
    QString base = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation);
    if (base.isEmpty())
        base = QDir::homePath() + QStringLiteral("/Library/Application Support");
    return QDir(base).filePath(QString::fromLatin1(kRelaySubdir));
}

bool DhunCommonsBackend::ensureTelegramDirectory(QString* error)
{
    const QString dir = telegramDirectory();
    if (!QDir().mkpath(dir)) {
        if (error)
            *error = QStringLiteral("Could not create the Telegram relay folder at %1.").arg(dir);
        return false;
    }
    if (telegramDir() != dir)
        setTelegramDir(dir);
    return true;
}

bool DhunCommonsBackend::ensureWalletDirectory(QString* error)
{
    const QString dir = walletDirectory();
    if (!QDir().mkpath(dir)) {
        if (error)
            *error = QStringLiteral("Could not create the wallet folder at %1.").arg(dir);
        return false;
    }
    setChainWalletPath(dir);
    return true;
}

bool DhunCommonsBackend::walletFilesExist() const
{
    const QString dir = const_cast<DhunCommonsBackend*>(this)->walletDirectory();
    return QFile::exists(QDir(dir).filePath(QString::fromLatin1(kConfigName)))
        && QFile::exists(QDir(dir).filePath(QString::fromLatin1(kStorageName)));
}

void DhunCommonsBackend::writeConfig(const QString& path) const
{
    QJsonObject sequencer;
    sequencer.insert(QStringLiteral("sequencer_addr"), QString::fromLatin1(kSequencer));
    sequencer.insert(QStringLiteral("basic_auth"), QJsonValue::Null);

    QJsonObject config;
    config.insert(QStringLiteral("seq_poll_timeout"), QStringLiteral("30s"));
    config.insert(QStringLiteral("seq_tx_poll_max_blocks"), 15);
    config.insert(QStringLiteral("seq_poll_max_retries"), 10);
    config.insert(QStringLiteral("seq_block_poll_max_amount"), 100);
    config.insert(QStringLiteral("sequencer"), sequencer);

    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    if (file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        file.write(QJsonDocument(config).toJson(QJsonDocument::Indented));
}

QString DhunCommonsBackend::loadRoleMapping() const
{
    QFile file(QDir(const_cast<DhunCommonsBackend*>(this)->walletDirectory())
                   .filePath(QString::fromLatin1(kMappingName)));
    if (!file.open(QIODevice::ReadOnly))
        return QStringLiteral("{}");
    const QJsonObject root = QJsonDocument::fromJson(file.readAll()).object();
    const QJsonObject roles = root.value(QStringLiteral("roles")).toObject();
    return QString::fromUtf8(QJsonDocument(roles).toJson(QJsonDocument::Compact));
}

bool DhunCommonsBackend::saveRoleMapping(const QString& json) const
{
    const QJsonObject roles = QJsonDocument::fromJson(json.toUtf8()).object();
    QJsonObject root;
    root.insert(QStringLiteral("version"), 1);
    root.insert(QStringLiteral("roles"), roles);
    QFile file(QDir(const_cast<DhunCommonsBackend*>(this)->walletDirectory())
                   .filePath(QString::fromLatin1(kMappingName)));
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return false;
    return file.write(QJsonDocument(root).toJson(QJsonDocument::Indented)) > 0;
}

QString DhunCommonsBackend::accountsPayload(bool* ok)
{
    bool balancesOk = true;
    QJsonObject mapping = QJsonDocument::fromJson(loadRoleMapping().toUtf8()).object();
    const QVariantList raw = modules().lez_core.list_accounts();

    QStringList publicIds;
    for (const QVariant& value : raw) {
        if (value.type() == QVariant::Map) {
            const QVariantMap map = value.toMap();
            if (map.value(QStringLiteral("is_public"), true).toBool())
                publicIds.append(map.value(QStringLiteral("account_id")).toString().toLower());
        } else {
            publicIds.append(value.toString().toLower());
        }
    }
    publicIds.removeAll(QString());
    publicIds.removeDuplicates();

    QHash<QString, QString> roleToId;
    QSet<QString> used;
    for (const Role& role : kRoles) {
        const QString key = QString::fromLatin1(role.key);
        const QString mapped = mapping.value(key).toString().toLower();
        if (publicIds.contains(mapped) && !used.contains(mapped)) {
            roleToId.insert(key, mapped);
            used.insert(mapped);
        }
    }
    for (const Role& role : kRoles) {
        const QString key = QString::fromLatin1(role.key);
        if (roleToId.contains(key))
            continue;
        for (const QString& id : publicIds) {
            if (!used.contains(id)) {
                roleToId.insert(key, id);
                used.insert(id);
                break;
            }
        }
    }

    QJsonObject nextMapping;
    for (const Role& role : kRoles) {
        const QString key = QString::fromLatin1(role.key);
        if (roleToId.contains(key))
            nextMapping.insert(key, roleToId.value(key));
    }
    if (nextMapping != mapping)
        saveRoleMapping(jsonCompact(nextMapping));

    QJsonArray accounts;
    for (const Role& role : kRoles) {
        const QString key = QString::fromLatin1(role.key);
        QJsonObject entry;
        entry.insert(QStringLiteral("role"), key);
        entry.insert(QStringLiteral("name"), QString::fromLatin1(role.name));
        if (!roleToId.contains(key)) {
            entry.insert(QStringLiteral("hasAccount"), false);
            entry.insert(QStringLiteral("address"), QString());
            entry.insert(QStringLiteral("balance"), QString());
            entry.insert(QStringLiteral("balanceLepta"), QString());
            accounts.append(entry);
            continue;
        }

        const QString id = roleToId.value(key);
        entry.insert(QStringLiteral("hasAccount"), true);
        entry.insert(QStringLiteral("idHex"), id);

        const QString address = modules().lez_core.account_id_to_base58(id);
        entry.insert(QStringLiteral("address"), address.isEmpty() ? id : address);

        const QString lepta = modules().lez_core.get_balance(id, true).trimmed();
        if (lepta.isEmpty()) {
            entry.insert(QStringLiteral("balance"), QStringLiteral("—"));
            entry.insert(QStringLiteral("balanceLepta"), QString());
            balancesOk = false;
        } else {
            entry.insert(QStringLiteral("balanceLepta"), lepta);
            const QString tokens = leptaToToken(lepta);
            entry.insert(QStringLiteral("balance"), tokens.isEmpty() ? QStringLiteral("—") : tokens);
            if (tokens.isEmpty())
                balancesOk = false;
        }
        accounts.append(entry);
    }

    if (ok)
        *ok = balancesOk && !publicIds.isEmpty();
    return QString::fromUtf8(QJsonDocument(accounts).toJson(QJsonDocument::Compact));
}

void DhunCommonsBackend::setFailure(const QString& notice, const QString& status)
{
    setChainStatus(status);
    setChainNotice(notice);
}

bool DhunCommonsBackend::moduleReady() const
{
    if (!m_contextReady)
        return false;
    return !const_cast<DhunCommonsBackend*>(this)->modules().lez_core.version().isEmpty();
}

void DhunCommonsBackend::onContextReady()
{
    m_contextReady = true;
    setChainNetwork(QStringLiteral("LEZ public testnet"));
    setChainSequencer(QString::fromLatin1(kSequencer));
    setTelegramDir(telegramDirectory());
    QTimer::singleShot(600, this, [this]() { autoOpen(0); });
}

void DhunCommonsBackend::autoOpen(int attempt)
{
    if (m_walletOpen)
        return;
    if (!moduleReady()) {
        if (attempt < 20) {
            QTimer::singleShot(250, this, [this, attempt]() { autoOpen(attempt + 1); });
            return;
        }
        setFailure(QStringLiteral("The LEZ core module did not become ready. Install the lez_core LGX and reopen Dhun Commons."));
        return;
    }

    setChainWalletPath(walletDirectory());
    if (!walletFilesExist()) {
        setChainStatus(QStringLiteral("no-wallet"));
        setChainNotice(QStringLiteral("No on-device LEZ wallet yet. Create one to put the three party accounts on the public testnet."));
        return;
    }

    const qint64 error = modules().lez_core.open(
        QDir(walletDirectory()).filePath(QString::fromLatin1(kConfigName)),
        QDir(walletDirectory()).filePath(QString::fromLatin1(kStorageName)));
    if (error != 0) {
        setFailure(QStringLiteral("The saved wallet could not be opened (wallet error %1).").arg(error));
        return;
    }

    m_walletOpen = true;
    setChainStatus(QStringLiteral("ready"));
    setChainNotice(QStringLiteral("Wallet open on the public testnet. Refresh to read the latest block and balances."));
}

QString DhunCommonsBackend::createWallet(QString password)
{
    if (!m_contextReady || !moduleReady())
        return jsonCompact(failureObject(QStringLiteral("The LEZ core module is not ready. Reopen Basecamp and try again.")));
    if (m_walletOpen) {
        QJsonObject obj = failureObject(QStringLiteral("A wallet is already open on this device."));
        obj.insert(QStringLiteral("accounts"), QJsonDocument::fromJson(chainAccounts().toUtf8()).array());
        return jsonCompact(obj);
    }
    if (walletFilesExist())
        return openWallet();
    if (password.size() < 8)
        return jsonCompact(failureObject(QStringLiteral("Choose a password of at least 8 characters. It is used only when creating the wallet file.")));

    QString dirError;
    if (!ensureWalletDirectory(&dirError))
        return jsonCompact(failureObject(dirError));

    const QString configPath = QDir(walletDirectory()).filePath(QString::fromLatin1(kConfigName));
    const QString storagePath = QDir(walletDirectory()).filePath(QString::fromLatin1(kStorageName));
    writeConfig(configPath);

    const QString mnemonic = modules().lez_core.create_new(configPath, storagePath, password);
    if (mnemonic.isEmpty()) {
        QFile::remove(configPath);
        QFile::remove(storagePath);
        setFailure(QStringLiteral("The wallet could not be created. No recovery phrase was produced."));
        return jsonCompact(failureObject(QStringLiteral("The wallet could not be created. No recovery phrase was produced.")));
    }
    m_walletOpen = true;

    QJsonObject mapping;
    QJsonArray localAccounts;
    QStringList created;
    for (const Role& role : kRoles) {
        const QString id = modules().lez_core.create_account_public().toLower();
        if (id.isEmpty())
            break;
        mapping.insert(QString::fromLatin1(role.key), id);
        created.append(id);

        QJsonObject entry;
        entry.insert(QStringLiteral("role"), QString::fromLatin1(role.key));
        entry.insert(QStringLiteral("name"), QString::fromLatin1(role.name));
        entry.insert(QStringLiteral("hasAccount"), true);
        entry.insert(QStringLiteral("idHex"), id);
        const QString address = modules().lez_core.account_id_to_base58(id);
        entry.insert(QStringLiteral("address"), address.isEmpty() ? id : address);
        entry.insert(QStringLiteral("balance"), QStringLiteral("—"));
        entry.insert(QStringLiteral("balanceLepta"), QString());
        localAccounts.append(entry);
    }
    saveRoleMapping(jsonCompact(mapping));
    const qint64 saveError = modules().lez_core.save();

    setChainAccounts(QString::fromUtf8(QJsonDocument(localAccounts).toJson(QJsonDocument::Compact)));
    setChainStatus(QStringLiteral("ready"));
    setChainWalletPath(walletDirectory());

    QJsonObject result;
    result.insert(QStringLiteral("success"), created.size() == 3 && saveError == 0);
    result.insert(QStringLiteral("mnemonic"), mnemonic);
    result.insert(QStringLiteral("accounts"), localAccounts);
    result.insert(QStringLiteral("walletPath"), walletDirectory());
    result.insert(QStringLiteral("sequencer"), QString::fromLatin1(kSequencer));
    if (created.size() != 3) {
        result.insert(QStringLiteral("error"), QStringLiteral("The wallet was created, but only %1 of 3 party accounts were produced.").arg(created.size()));
        setChainNotice(QStringLiteral("Wallet created, but only %1 of 3 party accounts were produced.").arg(created.size()));
    } else if (saveError != 0) {
        result.insert(QStringLiteral("error"), QStringLiteral("The wallet was created but could not be saved (wallet error %1). Save the recovery phrase before quitting.").arg(saveError));
        setChainNotice(QStringLiteral("Wallet created but not saved (wallet error %1). Save the recovery phrase before quitting.").arg(saveError));
    } else {
        setChainNotice(QStringLiteral("Wallet created with three public accounts. Save the recovery phrase, then refresh to read testnet balances."));
    }
    return jsonCompact(result);
}

QString DhunCommonsBackend::openWallet()
{
    if (!m_contextReady || !moduleReady())
        return jsonCompact(failureObject(QStringLiteral("The LEZ core module is not ready.")));
    if (m_walletOpen) {
        QJsonObject obj;
        obj.insert(QStringLiteral("success"), true);
        obj.insert(QStringLiteral("alreadyOpen"), true);
        obj.insert(QStringLiteral("walletPath"), walletDirectory());
        obj.insert(QStringLiteral("accounts"), QJsonDocument::fromJson(chainAccounts().toUtf8()).array());
        return jsonCompact(obj);
    }
    if (!walletFilesExist()) {
        setFailure(QStringLiteral("No wallet files were found at %1.").arg(walletDirectory()), QStringLiteral("no-wallet"));
        return jsonCompact(failureObject(QStringLiteral("No wallet files were found at %1.").arg(walletDirectory())));
    }

    const qint64 error = modules().lez_core.open(
        QDir(walletDirectory()).filePath(QString::fromLatin1(kConfigName)),
        QDir(walletDirectory()).filePath(QString::fromLatin1(kStorageName)));
    if (error != 0) {
        setFailure(QStringLiteral("The wallet could not be opened (wallet error %1).").arg(error));
        return jsonCompact(failureObject(QStringLiteral("The wallet could not be opened (wallet error %1).").arg(error)));
    }

    m_walletOpen = true;
    setChainStatus(QStringLiteral("ready"));
    setChainWalletPath(walletDirectory());
    setChainNotice(QStringLiteral("Wallet open. Refresh to read the latest block and balances."));

    QJsonObject obj;
    obj.insert(QStringLiteral("success"), true);
    obj.insert(QStringLiteral("walletPath"), walletDirectory());
    obj.insert(QStringLiteral("sequencer"), QString::fromLatin1(kSequencer));
    return jsonCompact(obj);
}

QString DhunCommonsBackend::refreshChain()
{
    if (!m_walletOpen) {
        QJsonObject obj = failureObject(QStringLiteral("Open or create the LEZ wallet first."));
        obj.insert(QStringLiteral("status"), chainStatus());
        return jsonCompact(obj);
    }

    m_busy = true;
    setChainBusy(true);
    setChainNotice(QStringLiteral("Reading the public testnet…"));

    const qint64 height = modules().lez_core.get_current_block_height();
    setChainHeight(static_cast<int>(qMax<qint64>(0, height)));

    bool accountsOk = false;
    const QString payload = accountsPayload(&accountsOk);
    setChainAccounts(payload);

    const QString sequencer = modules().lez_core.get_sequencer_addr();
    if (!sequencer.isEmpty())
        setChainSequencer(sequencer);

    m_busy = false;
    setChainBusy(false);

    QJsonObject result;
    result.insert(QStringLiteral("success"), accountsOk && height > 0);
    result.insert(QStringLiteral("height"), static_cast<double>(height));
    result.insert(QStringLiteral("accounts"), QJsonDocument::fromJson(payload.toUtf8()).array());
    result.insert(QStringLiteral("walletPath"), walletDirectory());
    result.insert(QStringLiteral("sequencer"), chainSequencer());
    if (height <= 0) {
        result.insert(QStringLiteral("error"), QStringLiteral("The testnet block height could not be read."));
        setChainStatus(QStringLiteral("ready"));
        setChainNotice(QStringLiteral("Wallet open, but the testnet height could not be read. Check the network and refresh."));
    } else if (!accountsOk) {
        result.insert(QStringLiteral("error"), QStringLiteral("Some public balances could not be read from the testnet."));
        setChainStatus(QStringLiteral("ready"));
        setChainNotice(QStringLiteral("Block %1 read, but at least one balance query failed. Refresh to retry.").arg(height));
    } else {
        setChainStatus(QStringLiteral("ready"));
        setChainNotice(QStringLiteral("Read from the LEZ public testnet. Latest observed block: %1.").arg(height));
    }
    return jsonCompact(result);
}

QString DhunCommonsBackend::sendSettlement(QString fromAccountId,
                                          QString toAccountId,
                                          QString amount)
{
    if (!m_walletOpen)
        return jsonCompact(failureObject(QStringLiteral("Open the LEZ wallet before sending a settlement.")));

    const QString from = normaliseAccountId(fromAccountId);
    const QString to = normaliseAccountId(toAccountId);
    if (!isHexAccountId(from) || !isHexAccountId(to))
        return jsonCompact(failureObject(QStringLiteral("Both party accounts must be 32-byte account IDs.")));
    if (from == to)
        return jsonCompact(failureObject(QStringLiteral("Choose two different party accounts.")));

    QString amountError;
    const QString amountHex = tokenToLe16Hex(amount, &amountError);
    if (amountHex.isEmpty())
        return jsonCompact(failureObject(amountError));

    m_busy = true;
    setChainBusy(true);
    setChainNotice(QStringLiteral("Submitting a public transfer to the LEZ testnet…"));

    const QString raw = modules().lez_core.transfer_public(from, to, amountHex);
    QJsonObject parsed = QJsonDocument::fromJson(raw.toUtf8()).object();
    bool success = parsed.value(QStringLiteral("success")).toBool();
    QString txHash = parsed.value(QStringLiteral("tx_hash")).toString().trimmed();
    QString error = parsed.value(QStringLiteral("error")).toString();
    if (raw.isEmpty()) {
        success = false;
        error = QStringLiteral("The wallet returned no transfer result.");
    } else if (parsed.isEmpty()) {
        success = false;
        error = raw;
    }
    if (success && txHash.isEmpty()) {
        success = false;
        error = QStringLiteral("The wallet reported success without returning a transaction hash. Treat this as unconfirmed.");
    }
    if (!success) {
        if (error.contains(QStringLiteral("wallet FFI error 9")))
            error = QStringLiteral("Insufficient funds: this account has no spendable LEZ on the testnet. Fund it externally before sending.");
        else if (error.contains(QStringLiteral("wallet FFI error 18")))
            error = QStringLiteral("The sender cannot cover the testnet fee reserve.");
        else if (error.contains(QStringLiteral("wallet FFI error 6")))
            error = QStringLiteral("The sequencer could not be reached. Check the network and try again.");
    }

    QJsonObject last;
    last.insert(QStringLiteral("success"), success);
    last.insert(QStringLiteral("txHash"), txHash);
    last.insert(QStringLiteral("error"), error);
    last.insert(QStringLiteral("amount"), amount.trimmed());
    last.insert(QStringLiteral("amountLeptaHex"), amountHex);
    last.insert(QStringLiteral("from"), from);
    last.insert(QStringLiteral("to"), to);
    last.insert(QStringLiteral("at"), static_cast<double>(QDateTime::currentMSecsSinceEpoch()));
    last.insert(QStringLiteral("confirmed"), false);
    setChainLastTx(jsonCompact(last));

    m_busy = false;
    setChainBusy(false);

    QJsonObject result = last;
    if (success) {
        setChainStatus(QStringLiteral("ready"));
        setChainNotice(QStringLiteral("Transfer submitted. Verify the hash before treating it as settled."));
    } else {
        setChainStatus(QStringLiteral("ready"));
        setChainNotice(QStringLiteral("Transfer not submitted: %1").arg(error));
    }
    return jsonCompact(result);
}

QString DhunCommonsBackend::checkTransaction(QString txHash)
{
    const QString hash = txHash.trimmed();
    static const QRegularExpression re(QStringLiteral("^[0-9a-fA-F]{64}$"));
    if (!re.match(hash).hasMatch())
        return jsonCompact(failureObject(QStringLiteral("A transaction hash is 32 bytes of hex.")));
    if (!m_walletOpen)
        return jsonCompact(failureObject(QStringLiteral("Open the LEZ wallet first.")));

    m_busy = true;
    setChainBusy(true);
    setChainNotice(QStringLiteral("Checking the transaction with the sequencer…"));
    const bool found = modules().lez_core.poll_transaction_status(hash);
    m_busy = false;
    setChainBusy(false);

    QJsonObject last = QJsonDocument::fromJson(chainLastTx().toUtf8()).object();
    if (!last.isEmpty() && last.value(QStringLiteral("txHash")).toString().compare(hash, Qt::CaseInsensitive) == 0) {
        last.insert(QStringLiteral("confirmed"), found);
        setChainLastTx(jsonCompact(last));
    }

    QJsonObject result;
    result.insert(QStringLiteral("success"), found);
    result.insert(QStringLiteral("found"), found);
    result.insert(QStringLiteral("txHash"), hash);
    if (!found)
        result.insert(QStringLiteral("error"), QStringLiteral("The sequencer did not report this transaction."));
    setChainNotice(found
        ? QStringLiteral("The sequencer reported the transaction. Check the explorer for finality.")
        : QStringLiteral("The sequencer did not report this transaction. Do not treat it as settled."));
    return jsonCompact(result);
}

QString DhunCommonsBackend::chainDetails()
{
    QJsonObject obj;
    obj.insert(QStringLiteral("status"), chainStatus());
    obj.insert(QStringLiteral("notice"), chainNotice());
    obj.insert(QStringLiteral("network"), chainNetwork());
    obj.insert(QStringLiteral("sequencer"), chainSequencer());
    obj.insert(QStringLiteral("height"), chainHeight());
    obj.insert(QStringLiteral("walletPath"), walletDirectory());
    obj.insert(QStringLiteral("walletOpen"), m_walletOpen);
    obj.insert(QStringLiteral("accounts"), QJsonDocument::fromJson(chainAccounts().toUtf8()).array());
    obj.insert(QStringLiteral("lastTx"), QJsonDocument::fromJson(chainLastTx().toUtf8()).object());
    return jsonCompact(obj);
}

QString DhunCommonsBackend::publishTelegramState(QString json)
{
    if (json.toUtf8().size() > kMaxTelegramSnapshot)
        return jsonCompact(failureObject(QStringLiteral("The Telegram relay snapshot is too large.")));

    QJsonParseError parseError;
    const QJsonDocument document = QJsonDocument::fromJson(json.toUtf8(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.isObject())
        return jsonCompact(failureObject(QStringLiteral("The Telegram relay snapshot is not a JSON object.")));

    QString error;
    if (!ensureTelegramDirectory(&error))
        return jsonCompact(failureObject(error));

    QJsonObject payload = document.object();
    payload.insert(QStringLiteral("publishedAt"), static_cast<double>(QDateTime::currentMSecsSinceEpoch()));
    payload.insert(QStringLiteral("source"), QStringLiteral("dhun_commons"));

    const QString path = QDir(telegramDirectory()).filePath(QStringLiteral("state.json"));
    QSaveFile file(path);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return jsonCompact(failureObject(QStringLiteral("Could not open the relay snapshot for writing.")));
    file.write(QJsonDocument(payload).toJson(QJsonDocument::Indented));
    if (!file.commit())
        return jsonCompact(failureObject(QStringLiteral("Could not save the relay snapshot at %1.").arg(path)));

    QJsonObject result;
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("dir"), telegramDirectory());
    result.insert(QStringLiteral("path"), path);
    return jsonCompact(result);
}

QString DhunCommonsBackend::telegramInbox()
{
    QString error;
    if (!ensureTelegramDirectory(&error))
        return jsonCompact(failureObject(error));

    const QDir dir(telegramDirectory());
    QJsonArray messages;
    QFile inbox(dir.filePath(QStringLiteral("inbox.json")));
    if (inbox.open(QIODevice::ReadOnly)) {
        const QJsonDocument document = QJsonDocument::fromJson(inbox.readAll());
        if (document.isArray())
            messages = document.array();
        else if (document.isObject())
            messages = document.object().value(QStringLiteral("messages")).toArray();
    }

    QJsonArray trimmed;
    const int start = qMax(0, static_cast<int>(messages.size()) - 50);
    for (int i = start; i < messages.size(); ++i)
        trimmed.append(messages.at(i));

    QJsonObject bridge;
    QFile beat(dir.filePath(QStringLiteral("bridge.json")));
    if (beat.open(QIODevice::ReadOnly)) {
        const QJsonDocument document = QJsonDocument::fromJson(beat.read(8192));
        if (document.isObject())
            bridge = document.object();
    }

    QJsonObject result;
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("dir"), telegramDirectory());
    result.insert(QStringLiteral("messages"), trimmed);
    result.insert(QStringLiteral("bridge"), bridge);
    return jsonCompact(result);
}

QString DhunCommonsBackend::ackTelegramMessage(QString id)
{
    const QString key = id.trimmed();
    if (key.isEmpty())
        return jsonCompact(failureObject(QStringLiteral("A Telegram message id is required.")));

    QString error;
    if (!ensureTelegramDirectory(&error))
        return jsonCompact(failureObject(error));

    const QDir dir(telegramDirectory());
    const QString inboxPath = dir.filePath(QStringLiteral("inbox.json"));
    QJsonArray messages;
    QFile inbox(inboxPath);
    if (inbox.open(QIODevice::ReadOnly)) {
        const QJsonDocument document = QJsonDocument::fromJson(inbox.readAll());
        if (document.isArray())
            messages = document.array();
        else if (document.isObject())
            messages = document.object().value(QStringLiteral("messages")).toArray();
        inbox.close();
    }

    QJsonArray kept;
    bool removed = false;
    for (const QJsonValue& value : messages) {
        const QJsonObject entry = value.toObject();
        if (entry.value(QStringLiteral("id")).toString() == key) {
            removed = true;
            continue;
        }
        kept.append(entry);
    }

    if (removed) {
        QJsonObject root;
        root.insert(QStringLiteral("version"), 1);
        root.insert(QStringLiteral("messages"), kept);
        QSaveFile file(inboxPath);
        if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
            return jsonCompact(failureObject(QStringLiteral("Could not open the relay inbox for writing.")));
        file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
        if (!file.commit())
            return jsonCompact(failureObject(QStringLiteral("Could not update the relay inbox.")));

        QFile acked(dir.filePath(QStringLiteral("acked.json")));
        QJsonArray log;
        if (acked.open(QIODevice::ReadOnly)) {
            const QJsonDocument document = QJsonDocument::fromJson(acked.readAll());
            if (document.isArray())
                log = document.array();
            else if (document.isObject())
                log = document.object().value(QStringLiteral("acked")).toArray();
            acked.close();
        }
        QJsonObject record;
        record.insert(QStringLiteral("id"), key);
        record.insert(QStringLiteral("at"), static_cast<double>(QDateTime::currentMSecsSinceEpoch()));
        log.append(record);

        QJsonArray logTrimmed;
        const int logStart = qMax(0, static_cast<int>(log.size()) - 200);
        for (int i = logStart; i < log.size(); ++i)
            logTrimmed.append(log.at(i));
        QJsonObject logRoot;
        logRoot.insert(QStringLiteral("version"), 1);
        logRoot.insert(QStringLiteral("acked"), logTrimmed);
        QSaveFile logFile(dir.filePath(QStringLiteral("acked.json")));
        if (logFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            logFile.write(QJsonDocument(logRoot).toJson(QJsonDocument::Indented));
            logFile.commit();
        }
    }

    QJsonObject result;
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("removed"), removed);
    result.insert(QStringLiteral("remaining"), static_cast<int>(kept.size()));
    return jsonCompact(result);
}

QString DhunCommonsBackend::signalRelayDirectory() const
{
    // The Signal bridge writes into the same relay folder as the Telegram
    // bridge; only the file names differ (asks.json / signal_bridge.json).
    return telegramDirectory();
}

bool DhunCommonsBackend::ensureSignalRelayDirectory(QString* error)
{
    return ensureTelegramDirectory(error);
}

QString DhunCommonsBackend::signalRelay()
{
    QString error;
    if (!ensureSignalRelayDirectory(&error))
        return jsonCompact(failureObject(error));

    const QDir dir(signalRelayDirectory());

    QJsonArray asks;
    QFile asksFile(dir.filePath(QStringLiteral("asks.json")));
    if (asksFile.open(QIODevice::ReadOnly)) {
        const QJsonDocument document = QJsonDocument::fromJson(asksFile.readAll());
        if (document.isArray())
            asks = document.array();
        else if (document.isObject())
            asks = document.object().value(QStringLiteral("asks")).toArray();
    }

    QSet<QString> answered;
    QFile answersFile(dir.filePath(QStringLiteral("answers.json")));
    if (answersFile.open(QIODevice::ReadOnly)) {
        const QJsonDocument document = QJsonDocument::fromJson(answersFile.readAll());
        QJsonArray answers = document.isArray()
            ? document.array()
            : document.object().value(QStringLiteral("answers")).toArray();
        for (const QJsonValue& value : answers) {
            const QString id = value.toObject().value(QStringLiteral("id")).toString();
            if (!id.isEmpty())
                answered.insert(id);
        }
    }

    QJsonArray pending;
    for (const QJsonValue& value : asks) {
        const QJsonObject ask = value.toObject();
        const QString id = ask.value(QStringLiteral("id")).toString();
        if (id.isEmpty() || answered.contains(id))
            continue;
        pending.append(ask);
    }
    const int start = qMax(0, static_cast<int>(pending.size()) - 10);
    QJsonArray trimmed;
    for (int i = start; i < pending.size(); ++i)
        trimmed.append(pending.at(i));

    QJsonObject bridge;
    QFile beat(dir.filePath(QStringLiteral("signal_bridge.json")));
    if (beat.open(QIODevice::ReadOnly)) {
        const QJsonDocument document = QJsonDocument::fromJson(beat.read(8192));
        if (document.isObject())
            bridge = document.object();
    }

    QJsonObject result;
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("dir"), signalRelayDirectory());
    result.insert(QStringLiteral("asks"), trimmed);
    result.insert(QStringLiteral("pending"), static_cast<int>(trimmed.size()));
    result.insert(QStringLiteral("bridge"), bridge);
    return jsonCompact(result);
}

QString DhunCommonsBackend::publishSignalAnswer(QString id, QString text)
{
    const QString key = id.trimmed();
    if (key.isEmpty())
        return jsonCompact(failureObject(QStringLiteral("A Signal ask id is required.")));
    QString body = text.trimmed();
    if (body.isEmpty())
        return jsonCompact(failureObject(QStringLiteral("The Signal answer is empty.")));
    if (body.size() > kMaxSignalAnswerChars)
        body = body.left(kMaxSignalAnswerChars);

    QString error;
    if (!ensureSignalRelayDirectory(&error))
        return jsonCompact(failureObject(error));

    const QDir dir(signalRelayDirectory());
    const QString answersPath = dir.filePath(QStringLiteral("answers.json"));

    QJsonArray answers;
    QFile existing(answersPath);
    if (existing.open(QIODevice::ReadOnly)) {
        const QJsonDocument document = QJsonDocument::fromJson(existing.readAll());
        answers = document.isArray()
            ? document.array()
            : document.object().value(QStringLiteral("answers")).toArray();
        existing.close();
    }

    QJsonArray kept;
    for (const QJsonValue& value : answers) {
        if (value.toObject().value(QStringLiteral("id")).toString() == key)
            continue;
        kept.append(value);
    }
    const int start = qMax(0, static_cast<int>(kept.size()) - 49);
    QJsonArray keptTrimmed;
    for (int i = start; i < kept.size(); ++i)
        keptTrimmed.append(kept.at(i));

    QJsonObject entry;
    entry.insert(QStringLiteral("id"), key);
    entry.insert(QStringLiteral("channel"), QStringLiteral("signal"));
    entry.insert(QStringLiteral("text"), body);
    entry.insert(QStringLiteral("source"), QStringLiteral("dhun_commons"));
    entry.insert(QStringLiteral("at"), static_cast<double>(QDateTime::currentMSecsSinceEpoch()));
    keptTrimmed.append(entry);

    QJsonObject root;
    root.insert(QStringLiteral("version"), 1);
    root.insert(QStringLiteral("answers"), keptTrimmed);
    QSaveFile file(answersPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Truncate))
        return jsonCompact(failureObject(QStringLiteral("Could not open the Signal answers file for writing.")));
    file.write(QJsonDocument(root).toJson(QJsonDocument::Indented));
    if (!file.commit())
        return jsonCompact(failureObject(QStringLiteral("Could not save the Signal answer.")));

    const QString asksPath = dir.filePath(QStringLiteral("asks.json"));
    QJsonArray asks;
    QFile asksFile(asksPath);
    if (asksFile.open(QIODevice::ReadOnly)) {
        const QJsonDocument document = QJsonDocument::fromJson(asksFile.readAll());
        asks = document.isArray()
            ? document.array()
            : document.object().value(QStringLiteral("asks")).toArray();
        asksFile.close();
    }
    QJsonArray asksKept;
    bool removedAsk = false;
    for (const QJsonValue& value : asks) {
        if (value.toObject().value(QStringLiteral("id")).toString() == key) {
            removedAsk = true;
            continue;
        }
        asksKept.append(value);
    }
    if (removedAsk) {
        QJsonObject askRoot;
        askRoot.insert(QStringLiteral("version"), 1);
        askRoot.insert(QStringLiteral("asks"), asksKept);
        QSaveFile askFile(asksPath);
        if (askFile.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
            askFile.write(QJsonDocument(askRoot).toJson(QJsonDocument::Indented));
            askFile.commit();
        }
    }

    QJsonObject result;
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("id"), key);
    result.insert(QStringLiteral("path"), answersPath);
    result.insert(QStringLiteral("removedAsk"), removedAsk);
    return jsonCompact(result);
}

bool DhunCommonsBackend::readPhotoBytes(const QString& path,
                                        QByteArray* bytes,
                                        QString* mime,
                                        QString* error) const
{
    const QString requested = path.trimmed();
    if (requested.isEmpty()) {
        *error = QStringLiteral("Choose a menu photo first.");
        return false;
    }

    const QFileInfo info(requested);
    const QString resolved = info.canonicalFilePath();
    if (resolved.isEmpty() || !info.isFile()) {
        *error = QStringLiteral("The chosen photo is not a readable file.");
        return false;
    }

    const qint64 maxBytes = 8 * 1024 * 1024;
    if (info.size() <= 0) {
        *error = QStringLiteral("The chosen photo is empty.");
        return false;
    }
    if (info.size() > maxBytes) {
        *error = QStringLiteral("The photo is larger than 8 MB. Choose a smaller image.");
        return false;
    }

    const QString suffix = info.suffix().toLower();
    if (suffix == QStringLiteral("png"))
        *mime = QStringLiteral("image/png");
    else if (suffix == QStringLiteral("jpg") || suffix == QStringLiteral("jpeg"))
        *mime = QStringLiteral("image/jpeg");
    else if (suffix == QStringLiteral("webp"))
        *mime = QStringLiteral("image/webp");
    else {
        *error = QStringLiteral("Only PNG, JPEG or WebP menu photos can be read. Convert HEIC before choosing it.");
        return false;
    }

    QFile file(resolved);
    if (!file.open(QIODevice::ReadOnly)) {
        *error = QStringLiteral("The chosen photo could not be opened.");
        return false;
    }
    *bytes = file.readAll();
    file.close();
    if (bytes->isEmpty()) {
        *error = QStringLiteral("The chosen photo is empty.");
        return false;
    }
    if (bytes->size() > maxBytes) {
        *error = QStringLiteral("The photo is larger than 8 MB. Choose a smaller image.");
        return false;
    }
    return true;
}

QString DhunCommonsBackend::readPhotoBase64(QString path)
{
    QByteArray bytes;
    QString mime;
    QString error;
    if (!readPhotoBytes(path, &bytes, &mime, &error))
        return jsonCompact(failureObject(error));

    QJsonObject result;
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("mime"), mime);
    result.insert(QStringLiteral("bytes"), static_cast<double>(bytes.size()));
    result.insert(QStringLiteral("base64"), QString::fromLatin1(bytes.toBase64()));
    return jsonCompact(result);
}

bool DhunCommonsBackend::loopbackChatUrl(const QString& endpoint, QString* url, QString* error) const
{
    const QUrl parsed(endpoint.trimmed());
    const QString scheme = parsed.scheme().toLower();
    const QString host = parsed.host().toLower();
    const bool loopback = host == QStringLiteral("127.0.0.1")
        || host == QStringLiteral("localhost")
        || host == QStringLiteral("::1");
    if ((scheme != QStringLiteral("http") && scheme != QStringLiteral("https")) || !loopback) {
        *error = QStringLiteral("Only a loopback endpoint such as http://127.0.0.1:11434/v1 is allowed.");
        return false;
    }

    QString base = parsed.adjusted(QUrl::RemoveQuery | QUrl::RemoveFragment | QUrl::NormalizePathSegments).toString();
    while (base.endsWith(QLatin1Char('/')))
        base.chop(1);
    if (base.endsWith(QStringLiteral("/v1/chat/completions")))
        *url = base;
    else if (base.endsWith(QStringLiteral("/v1")))
        *url = base + QStringLiteral("/chat/completions");
    else
        *url = base + QStringLiteral("/v1/chat/completions");
    return true;
}

QString DhunCommonsBackend::probeModelServer(QString endpoint)
{
    QString chatUrl;
    QString error;
    if (!loopbackChatUrl(endpoint, &chatUrl, &error))
        return jsonCompact(failureObject(error));

    QString modelsUrl = chatUrl;
    modelsUrl.replace(QRegularExpression(QStringLiteral("/chat/completions$")),
                      QStringLiteral("/models"));

    QNetworkAccessManager network;
    QNetworkRequest request{QUrl(modelsUrl)};
    request.setTransferTimeout(4000);
    QNetworkReply* reply = network.get(request);
    QEventLoop loop;
    QTimer guard;
    guard.setSingleShot(true);
    QObject::connect(&guard, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    guard.start(5000);
    loop.exec();

    QJsonObject result;
    if (!reply->isFinished()) {
        reply->abort();
        reply->deleteLater();
        result = failureObject(QStringLiteral("The local model server did not answer within 5 seconds."));
        return jsonCompact(result);
    }

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    const QString networkError = reply->errorString();
    const bool failed = reply->error() != QNetworkReply::NoError && status == 0;
    reply->deleteLater();

    if (failed) {
        result = failureObject(QStringLiteral("No local model server replied: ") + networkError);
        result.insert(QStringLiteral("url"), modelsUrl);
        return jsonCompact(result);
    }
    if (status < 200 || status >= 300) {
        result = failureObject(QStringLiteral("The local model server replied with HTTP ") + QString::number(status) + QLatin1Char('.'));
        result.insert(QStringLiteral("status"), status);
        return jsonCompact(result);
    }

    QJsonArray names;
    const QJsonObject data = QJsonDocument::fromJson(body).object();
    const QJsonArray items = data.contains(QStringLiteral("data"))
        ? data.value(QStringLiteral("data")).toArray()
        : data.value(QStringLiteral("models")).toArray();
    for (const QJsonValue& item : items) {
        const QJsonObject entry = item.toObject();
        QString name = entry.value(QStringLiteral("id")).toString();
        if (name.isEmpty())
            name = entry.value(QStringLiteral("name")).toString();
        if (name.isEmpty())
            name = entry.value(QStringLiteral("model")).toString();
        if (!name.isEmpty() && names.size() < 6)
            names.append(name);
    }

    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("status"), status);
    result.insert(QStringLiteral("url"), modelsUrl);
    result.insert(QStringLiteral("models"), names);
    return jsonCompact(result);
}

QString DhunCommonsBackend::agroForecast(QString requestJson)
{
    QJsonObject request;
    const QJsonDocument requestDoc = QJsonDocument::fromJson(requestJson.toUtf8());
    if (requestDoc.isObject())
        request = requestDoc.object();

    double latitude = request.value(QStringLiteral("latitude")).toDouble(qQNaN());
    double longitude = request.value(QStringLiteral("longitude")).toDouble(qQNaN());
    if (!std::isfinite(latitude) || latitude < -90.0 || latitude > 90.0)
        latitude = 26.7113;
    if (!std::isfinite(longitude) || longitude < -180.0 || longitude > 180.0)
        longitude = 75.5901;
    const int days = qBound(1, request.value(QStringLiteral("days")).toInt(7), 14);

    QString timezone = request.value(QStringLiteral("timezone")).toString().trimmed();
    static const QRegularExpression tzPattern(QStringLiteral("^[A-Za-z][A-Za-z0-9_/+-]{0,63}$"));
    if (timezone.isEmpty() || !tzPattern.match(timezone).hasMatch())
        timezone = QStringLiteral("Asia/Kolkata");

    const QString cacheKey = QStringLiteral("%1|%2|%3|%4")
                                 .arg(latitude, 0, 'f', 3)
                                 .arg(longitude, 0, 'f', 3)
                                 .arg(days)
                                 .arg(timezone);
    static QHash<QString, AgroCacheEntry> cache;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    auto cached = cache.constFind(cacheKey);
    if (cached != cache.constEnd() && now - cached->savedAt < kAgroCacheMs) {
        QJsonObject payload = cached->payload;
        payload.insert(QStringLiteral("cached"), true);
        return jsonCompact(payload);
    }

    QUrl url(QString::fromLatin1(kOpenMeteoUrl));
    QUrlQuery query;
    query.addQueryItem(QStringLiteral("latitude"), QString::number(latitude, 'f', 4));
    query.addQueryItem(QStringLiteral("longitude"), QString::number(longitude, 'f', 4));
    query.addQueryItem(QStringLiteral("daily"), QString::fromLatin1(kAgroDailyVars));
    query.addQueryItem(QStringLiteral("current"), QString::fromLatin1(kAgroCurrentVars));
    query.addQueryItem(QStringLiteral("forecast_days"), QString::number(days));
    query.addQueryItem(QStringLiteral("wind_speed_unit"), QStringLiteral("kmh"));
    query.addQueryItem(QStringLiteral("timezone"), timezone);
    url.setQuery(query);

    QNetworkAccessManager network;
    QNetworkRequest httpRequest{url};
    httpRequest.setTransferTimeout(8000);
    QNetworkReply* reply = network.get(httpRequest);
    QEventLoop loop;
    QTimer guard;
    guard.setSingleShot(true);
    QObject::connect(&guard, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    guard.start(9000);
    loop.exec();

    if (!reply->isFinished()) {
        reply->abort();
        reply->deleteLater();
        QJsonObject failure = failureObject(QStringLiteral("The forecast service did not answer within 9 seconds."));
        failure.insert(QStringLiteral("source"), QStringLiteral("open-meteo"));
        return jsonCompact(failure);
    }

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    const QString networkError = reply->errorString();
    const bool failed = reply->error() != QNetworkReply::NoError && status == 0;
    reply->deleteLater();

    if (failed) {
        QJsonObject failure = failureObject(QStringLiteral("No forecast reply: ") + networkError);
        failure.insert(QStringLiteral("source"), QStringLiteral("open-meteo"));
        return jsonCompact(failure);
    }
    if (status < 200 || status >= 300) {
        QJsonObject failure = failureObject(QStringLiteral("The forecast service replied with HTTP ")
                                            + QString::number(status) + QLatin1Char('.'));
        failure.insert(QStringLiteral("source"), QStringLiteral("open-meteo"));
        failure.insert(QStringLiteral("status"), status);
        return jsonCompact(failure);
    }

    const QJsonObject root = QJsonDocument::fromJson(body).object();
    const QJsonObject daily = root.value(QStringLiteral("daily")).toObject();
    const QJsonArray dates = daily.value(QStringLiteral("time")).toArray();
    if (dates.isEmpty()) {
        QJsonObject failure = failureObject(QStringLiteral("The forecast reply carried no daily series."));
        failure.insert(QStringLiteral("source"), QStringLiteral("open-meteo"));
        return jsonCompact(failure);
    }

    QJsonArray outDays;
    for (int index = 0; index < dates.size() && index < days; ++index) {
        QJsonObject day;
        day.insert(QStringLiteral("date"), dates.at(index).toString());
        insertNumber(day, "code", seriesValue(daily, "weather_code", index));
        insertNumber(day, "tMax", seriesValue(daily, "temperature_2m_max", index));
        insertNumber(day, "tMin", seriesValue(daily, "temperature_2m_min", index));
        insertNumber(day, "apparentMax", seriesValue(daily, "apparent_temperature_max", index));
        insertNumber(day, "apparentMin", seriesValue(daily, "apparent_temperature_min", index));
        insertNumber(day, "rain", seriesValue(daily, "precipitation_sum", index));
        insertNumber(day, "chance", seriesValue(daily, "precipitation_probability_max", index));
        insertNumber(day, "wind", seriesValue(daily, "wind_speed_10m_max", index));
        insertNumber(day, "gust", seriesValue(daily, "wind_gusts_10m_max", index));
        insertNumber(day, "direction", seriesValue(daily, "wind_direction_10m_dominant", index));
        insertNumber(day, "rh", seriesValue(daily, "relative_humidity_2m_mean", index));
        insertNumber(day, "et0", seriesValue(daily, "et0_fao_evapotranspiration", index));
        insertNumber(day, "radiation", seriesValue(daily, "shortwave_radiation_sum", index));
        insertNumber(day, "uv", seriesValue(daily, "uv_index_max", index));
        insertNumber(day, "soil", seriesValue(daily, "soil_moisture_0_to_10cm_mean", index));
        insertNumber(day, "dew", seriesValue(daily, "dew_point_2m_mean", index));
        insertNumber(day, "cloud", seriesValue(daily, "cloud_cover_mean", index));
        outDays.append(day);
    }

    const QJsonObject source = root.value(QStringLiteral("current")).toObject();
    QJsonObject current;
    insertNumber(current, "temp", source.value(QStringLiteral("temperature_2m")).toDouble(qQNaN()));
    insertNumber(current, "rh", source.value(QStringLiteral("relative_humidity_2m")).toDouble(qQNaN()));
    insertNumber(current, "rain", source.value(QStringLiteral("precipitation")).toDouble(qQNaN()));
    insertNumber(current, "code", source.value(QStringLiteral("weather_code")).toDouble(qQNaN()));
    insertNumber(current, "wind", source.value(QStringLiteral("wind_speed_10m")).toDouble(qQNaN()));
    insertNumber(current, "gust", source.value(QStringLiteral("wind_gusts_10m")).toDouble(qQNaN()));
    insertNumber(current, "direction", source.value(QStringLiteral("wind_direction_10m")).toDouble(qQNaN()));
    insertNumber(current, "soil", source.value(QStringLiteral("soil_moisture_0_to_10cm")).toDouble(qQNaN()));
    insertNumber(current, "soilTemp", source.value(QStringLiteral("soil_temperature_6cm")).toDouble(qQNaN()));
    current.insert(QStringLiteral("observedAt"), source.value(QStringLiteral("time")).toString());

    QJsonObject response;
    response.insert(QStringLiteral("success"), true);
    response.insert(QStringLiteral("source"), QStringLiteral("open-meteo"));
    response.insert(QStringLiteral("attribution"), QStringLiteral("Forecast data by Open-Meteo (CC BY 4.0)"));
    response.insert(QStringLiteral("location"), request.value(QStringLiteral("location")).toString());
    response.insert(QStringLiteral("label"), request.value(QStringLiteral("label")).toString());
    response.insert(QStringLiteral("latitude"), latitude);
    response.insert(QStringLiteral("longitude"), longitude);
    response.insert(QStringLiteral("timezone"), timezone);
    response.insert(QStringLiteral("elevation"), root.value(QStringLiteral("elevation")).toDouble(qQNaN()));
    response.insert(QStringLiteral("fetchedAt"), now);
    response.insert(QStringLiteral("cached"), false);
    response.insert(QStringLiteral("units"), QJsonObject{
        {QStringLiteral("temp"), QStringLiteral("°C")},
        {QStringLiteral("rain"), QStringLiteral("mm")},
        {QStringLiteral("wind"), QStringLiteral("km/h")},
        {QStringLiteral("et0"), QStringLiteral("mm")},
        {QStringLiteral("soil"), QStringLiteral("m³/m³")},
        {QStringLiteral("uv"), QStringLiteral("index")}
    });
    response.insert(QStringLiteral("current"), current);
    response.insert(QStringLiteral("days"), outDays);

    cache.insert(cacheKey, AgroCacheEntry{now, response});
    return jsonCompact(response);
}

QString DhunCommonsBackend::startMenuPhoto(QString path,
                                           QString endpoint,
                                           QString model,
                                           QString prompt)
{
    QString chatUrl;
    QString error;
    if (!loopbackChatUrl(endpoint, &chatUrl, &error))
        return jsonCompact(failureObject(error));

    const QString name = model.trimmed();
    if (name.isEmpty()) {
        return jsonCompact(failureObject(
            QStringLiteral("Name the local vision model first (for example qwen2.5vl:3b).")));
    }

    QByteArray bytes;
    QString mime;
    if (!readPhotoBytes(path, &bytes, &mime, &error))
        return jsonCompact(failureObject(error));

    const QString instruction = prompt.trimmed();
    if (instruction.isEmpty())
        return jsonCompact(failureObject(QStringLiteral("The menu-reading instruction was empty.")));

    QJsonObject imageUrl;
    imageUrl.insert(QStringLiteral("url"),
                    QStringLiteral("data:") + mime + QStringLiteral(";base64,")
                        + QString::fromLatin1(bytes.toBase64()));
    QJsonObject textPart;
    textPart.insert(QStringLiteral("type"), QStringLiteral("text"));
    textPart.insert(QStringLiteral("text"), instruction);
    QJsonObject imagePart;
    imagePart.insert(QStringLiteral("type"), QStringLiteral("image_url"));
    imagePart.insert(QStringLiteral("image_url"), imageUrl);
    QJsonArray contentParts;
    contentParts.append(textPart);
    contentParts.append(imagePart);
    QJsonObject message;
    message.insert(QStringLiteral("role"), QStringLiteral("user"));
    message.insert(QStringLiteral("content"), contentParts);
    QJsonArray messages;
    messages.append(message);

    QJsonObject payload;
    payload.insert(QStringLiteral("model"), name);
    payload.insert(QStringLiteral("temperature"), 0);
    payload.insert(QStringLiteral("max_tokens"), 500);
    payload.insert(QStringLiteral("messages"), messages);

    QNetworkAccessManager network;
    QNetworkRequest request{QUrl(chatUrl)};
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(185000);

    const qint64 startedMs = QDateTime::currentMSecsSinceEpoch();
    QNetworkReply* reply = network.post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));

    QEventLoop loop;
    QTimer guard;
    guard.setSingleShot(true);
    QObject::connect(&guard, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    guard.start(190000);
    loop.exec();
    guard.stop();

    QJsonObject result;
    result.insert(QStringLiteral("model"), name);
    result.insert(QStringLiteral("seconds"),
                  (QDateTime::currentMSecsSinceEpoch() - startedMs) / 1000.0);

    if (!reply->isFinished()) {
        reply->abort();
        reply->deleteLater();
        result = failureObject(
            QStringLiteral("The local model did not answer in time. It may still be loading the image."));
        result.insert(QStringLiteral("model"), name);
        return jsonCompact(result);
    }

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    const QString networkError = reply->errorString();
    const bool transportFailed = reply->error() != QNetworkReply::NoError && status == 0;
    reply->deleteLater();

    result.insert(QStringLiteral("httpStatus"), status);

    if (transportFailed) {
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("The local model server did not answer: ") + networkError);
        return jsonCompact(result);
    }

    if (status < 200 || status >= 300) {
        QString detail = QString::fromUtf8(body).left(300).trimmed();
        if (detail.isEmpty())
            detail = networkError;
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("The local model returned HTTP ") + QString::number(status)
                          + (detail.isEmpty() ? QString() : QStringLiteral(": ") + detail));
        return jsonCompact(result);
    }

    const QJsonObject parsed = QJsonDocument::fromJson(body).object();
    const QJsonArray choices = parsed.value(QStringLiteral("choices")).toArray();
    QString content;
    if (!choices.isEmpty()) {
        const QJsonValue value = choices.first().toObject()
                                     .value(QStringLiteral("message")).toObject()
                                     .value(QStringLiteral("content"));
        if (value.isString()) {
            content = value.toString();
        } else if (value.isArray()) {
            QStringList parts;
            for (const QJsonValue& part : value.toArray()) {
                const QString text = part.toObject().value(QStringLiteral("text")).toString();
                if (!text.isEmpty())
                    parts.append(text);
            }
            content = parts.join(QLatin1Char(' '));
        }
    }

    if (content.trimmed().isEmpty()) {
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("The local model returned no text. Check the model name and try again."));
        return jsonCompact(result);
    }

    const QJsonObject usage = parsed.value(QStringLiteral("usage")).toObject();
    if (!usage.isEmpty())
        result.insert(QStringLiteral("usage"), usage);
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("content"), content);
    return jsonCompact(result);
}

DhunCommonsBackend::AiConfig DhunCommonsBackend::aiConfig() const
{
    AiConfig cfg;
    cfg.model = qEnvironmentVariable("OPENROUTER_MODEL").trimmed();
    cfg.referer = qEnvironmentVariable("OPENROUTER_SITE_URL").trimmed();
    cfg.title = qEnvironmentVariable("OPENROUTER_SITE_NAME").trimmed();
    cfg.key = qEnvironmentVariable("OPENROUTER_API_KEY").trimmed();
    if (!cfg.key.isEmpty())
        cfg.source = QStringLiteral("env");

    const QString overridePath = qEnvironmentVariable("DHUN_OPENROUTER_CONFIG").trimmed();
    cfg.configPath = overridePath.isEmpty()
        ? QDir(QDir::homePath() + QStringLiteral("/.config/dhun-commons"))
              .filePath(QStringLiteral("openrouter.json"))
        : overridePath;

    if (cfg.key.isEmpty()) {
        QFile file(cfg.configPath);
        if (file.open(QIODevice::ReadOnly)) {
            const QByteArray raw = file.read(64 * 1024);
            file.close();
            const QJsonObject stored = QJsonDocument::fromJson(raw).object();
            cfg.key = stored.value(QStringLiteral("apiKey")).toString().trimmed();
            if (cfg.key.isEmpty())
                cfg.key = stored.value(QStringLiteral("key")).toString().trimmed();
            if (cfg.model.isEmpty())
                cfg.model = stored.value(QStringLiteral("model")).toString().trimmed();
            if (cfg.referer.isEmpty())
                cfg.referer = stored.value(QStringLiteral("referer")).toString().trimmed();
            if (cfg.title.isEmpty())
                cfg.title = stored.value(QStringLiteral("title")).toString().trimmed();
            if (!cfg.key.isEmpty())
                cfg.source = QStringLiteral("file");
            const QFile::Permissions perms = QFileInfo(cfg.configPath).permissions();
            cfg.insecureFile = perms.testAnyFlag(QFileDevice::ReadGroup)
                || perms.testAnyFlag(QFileDevice::ReadOther)
                || perms.testAnyFlag(QFileDevice::WriteGroup)
                || perms.testAnyFlag(QFileDevice::WriteOther);
        }
    }

    if (cfg.model.isEmpty())
        cfg.model = QString::fromLatin1(kOpenRouterDefaultModel);
    if (cfg.referer.isEmpty())
        cfg.referer = QStringLiteral("https://dhun-commons.local");
    if (cfg.title.isEmpty())
        cfg.title = QStringLiteral("Dhun Commons");
    return cfg;
}

QJsonObject DhunCommonsBackend::localModelInfo()
{
    QString endpoint = qEnvironmentVariable("DHUN_LOCAL_MODEL_ENDPOINT").trimmed();
    if (endpoint.isEmpty())
        endpoint = QStringLiteral("http://127.0.0.1:11434/v1");

    QString chatUrl;
    QString error;
    if (!loopbackChatUrl(endpoint, &chatUrl, &error))
        return {};

    const QJsonObject probe = QJsonDocument::fromJson(probeModelServer(endpoint).toUtf8()).object();
    if (!probe.value(QStringLiteral("success")).toBool())
        return {};

    const QJsonArray models = probe.value(QStringLiteral("models")).toArray();
    QString model = qEnvironmentVariable("DHUN_LOCAL_MODEL").trimmed();
    if (model.isEmpty() && !models.isEmpty())
        model = models.first().toString().trimmed();
    if (model.isEmpty())
        return {};

    bool modelAvailable = false;
    for (const QJsonValue& value : models) {
        if (value.toString() == model) {
            modelAvailable = true;
            break;
        }
    }
    if (!modelAvailable)
        return {};

    QJsonObject result;
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("provider"), QStringLiteral("ollama"));
    result.insert(QStringLiteral("model"), model);
    result.insert(QStringLiteral("endpoint"), endpoint);
    return result;
}

QString DhunCommonsBackend::localAssistantChat(QJsonObject payload, QString model, QString endpoint)
{
    QString chatUrl;
    QString error;
    if (!loopbackChatUrl(endpoint, &chatUrl, &error))
        return jsonCompact(failureObject(error));
    if (model.trimmed().isEmpty())
        return jsonCompact(failureObject(QStringLiteral("No local chat model is available.")));

    QNetworkAccessManager network;
    QNetworkRequest httpRequest{QUrl(chatUrl)};
    httpRequest.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    httpRequest.setTransferTimeout(120000);

    const qint64 startedMs = QDateTime::currentMSecsSinceEpoch();
    QNetworkReply* reply = network.post(httpRequest, QJsonDocument(payload).toJson(QJsonDocument::Compact));

    QEventLoop loop;
    QTimer guard;
    guard.setSingleShot(true);
    QObject::connect(&guard, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    guard.start(125000);
    loop.exec();
    guard.stop();

    QJsonObject result;
    result.insert(QStringLiteral("model"), model);
    result.insert(QStringLiteral("provider"), QStringLiteral("ollama"));
    result.insert(QStringLiteral("seconds"),
                  (QDateTime::currentMSecsSinceEpoch() - startedMs) / 1000.0);

    if (!reply->isFinished()) {
        reply->abort();
        reply->deleteLater();
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"), QStringLiteral("The local model did not answer within 125 seconds."));
        return jsonCompact(result);
    }

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    const QString networkError = reply->errorString();
    const bool transportFailed = reply->error() != QNetworkReply::NoError && status == 0;
    reply->deleteLater();
    result.insert(QStringLiteral("httpStatus"), status);

    if (transportFailed) {
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"), QStringLiteral("The local model could not be reached: ") + networkError);
        return jsonCompact(result);
    }
    if (status < 200 || status >= 300) {
        QString detail = QString::fromUtf8(body).left(300).trimmed();
        if (detail.isEmpty())
            detail = networkError;
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"), QStringLiteral("The local model returned HTTP ")
                          + QString::number(status)
                          + (detail.isEmpty() ? QString() : QStringLiteral(": ") + detail));
        return jsonCompact(result);
    }

    const QJsonObject parsed = QJsonDocument::fromJson(body).object();
    const QJsonArray choices = parsed.value(QStringLiteral("choices")).toArray();
    QString content;
    if (!choices.isEmpty()) {
        const QJsonValue value = choices.first().toObject()
                                     .value(QStringLiteral("message")).toObject()
                                     .value(QStringLiteral("content"));
        if (value.isString()) {
            content = value.toString();
        } else if (value.isArray()) {
            QStringList parts;
            for (const QJsonValue& part : value.toArray()) {
                const QString text = part.toObject().value(QStringLiteral("text")).toString();
                if (!text.isEmpty())
                    parts.append(text);
            }
            content = parts.join(QLatin1Char(' '));
        }
    }
    if (content.trimmed().isEmpty()) {
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"), QStringLiteral("The local model returned no text."));
        return jsonCompact(result);
    }

    const QString servedModel = parsed.value(QStringLiteral("model")).toString().trimmed();
    if (!servedModel.isEmpty())
        result.insert(QStringLiteral("model"), servedModel);
    const QJsonObject usage = parsed.value(QStringLiteral("usage")).toObject();
    if (!usage.isEmpty())
        result.insert(QStringLiteral("usage"), usage);
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("content"), content);
    return jsonCompact(result);
}

QString DhunCommonsBackend::aiStatus()
{
    const QJsonObject xenia = xeniaState();
    if (xenia.value(QStringLiteral("ready")).toBool()) {
        QJsonObject result;
        result.insert(QStringLiteral("success"), true);
        result.insert(QStringLiteral("configured"), true);
        result.insert(QStringLiteral("provider"), QStringLiteral("xenia"));
        result.insert(QStringLiteral("source"), QStringLiteral("xenia"));
        result.insert(QStringLiteral("mode"), QStringLiteral("xenia-delivery"));
        result.insert(QStringLiteral("model"), xenia.value(QStringLiteral("model")).toString());
        result.insert(QStringLiteral("room"), xenia.value(QStringLiteral("room")).toString());
        result.insert(QStringLiteral("xenia"), xenia);
        result.insert(QStringLiteral("note"),
                      QStringLiteral("Answers come from Xenia over Logos delivery (room '%1'). "
                                     "The provider runs the local model; OpenRouter is only used "
                                     "if Xenia is unavailable.")
                          .arg(xenia.value(QStringLiteral("room")).toString()));
        return jsonCompact(result);
    }

    const QJsonObject local = localModelInfo();
    if (local.value(QStringLiteral("success")).toBool()) {
        QJsonObject result = local;
        result.insert(QStringLiteral("configured"), true);
        result.insert(QStringLiteral("source"), QStringLiteral("loopback"));
        result.insert(QStringLiteral("mode"), QStringLiteral("local-loopback"));
        result.insert(QStringLiteral("xenia"), xenia);
        result.insert(QStringLiteral("note"), QStringLiteral("Local inference is active. Prompts and context stay on this device; no OpenRouter key is needed."));
        return jsonCompact(result);
    }

    const AiConfig cfg = aiConfig();
    QJsonObject result;
    result.insert(QStringLiteral("xenia"), xenia);
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("configured"), !cfg.key.isEmpty());
    result.insert(QStringLiteral("source"), cfg.source);
    result.insert(QStringLiteral("model"), cfg.model);
    result.insert(QStringLiteral("provider"), cfg.key.isEmpty() ? QString() : QStringLiteral("openrouter"));
    result.insert(QStringLiteral("endpoint"), QString::fromLatin1(kOpenRouterUrl));
    result.insert(QStringLiteral("configPath"), cfg.configPath);
    result.insert(QStringLiteral("insecureFile"), cfg.insecureFile);
    result.insert(QStringLiteral("mode"), cfg.key.isEmpty()
                      ? QStringLiteral("built-in") : QStringLiteral("openrouter-remote"));
    result.insert(QStringLiteral("note"),
                  cfg.key.isEmpty()
                      ? QStringLiteral("No local model responded and no OpenRouter key is configured. Built-in guidance remains available; start a loopback model such as Ollama, or configure OpenRouter for remote inference.")
                      : QStringLiteral("Local inference was not available, so model requests go to openrouter.ai. Prompts leave this device; the key stays in the environment or private config file and is never logged."));
    if (cfg.insecureFile) {
        result.insert(QStringLiteral("warning"),
                      QStringLiteral("The OpenRouter config file is readable or writable by other "
                                     "users. Run chmod 600 on it."));
    }
    return jsonCompact(result);
}

QJsonObject DhunCommonsBackend::xeniaState()
{
    QJsonObject state;
    state.insert(QStringLiteral("success"), false);
    state.insert(QStringLiteral("available"), false);
    state.insert(QStringLiteral("ready"), false);
    if (!m_contextReady) {
        state.insert(QStringLiteral("error"),
                     QStringLiteral("The module backend is not ready inside Basecamp."));
        return state;
    }

    const QString identityJson = modules().inference.identityStatus();
    const QJsonObject identity = QJsonDocument::fromJson(identityJson.toUtf8()).object();
    if (identity.isEmpty()) {
        state.insert(QStringLiteral("error"),
                     QStringLiteral("The Xenia inference module did not answer. Install the "
                                    "inference LGX in Basecamp and reopen Dhun Commons."));
        return state;
    }

    state.insert(QStringLiteral("success"), true);
    state.insert(QStringLiteral("available"), true);
    const bool initialized = identity.value(QStringLiteral("initialized")).toBool();
    const bool locked = identity.value(QStringLiteral("locked")).toBool();
    state.insert(QStringLiteral("initialized"), initialized);
    state.insert(QStringLiteral("locked"), locked);
    state.insert(QStringLiteral("fingerprint"), identity.value(QStringLiteral("fingerprint")).toString());
    state.insert(QStringLiteral("backend"), identity.value(QStringLiteral("backend")).toString());
    // Readiness needs a live provider, which needs the delivery node subscribed,
    // and nothing else starts it: without this the roster stays empty forever
    // and the assistant can never route through Xenia. startDelivery is
    // idempotent, so polling status is a safe place to own the side effect.
    if (modules().inference.deliveryStatus() == 0)
        modules().inference.startDelivery();

    state.insert(QStringLiteral("deliveryStatus"), modules().inference.deliveryStatus());
    state.insert(QStringLiteral("room"), modules().inference.room());

    const QJsonArray providers =
        QJsonDocument::fromJson(modules().inference.listProviders().toUtf8()).array();
    int live = 0;
    QString liveModel;
    for (const QJsonValue& value : providers) {
        const QJsonObject provider = value.toObject();
        if (!provider.value(QStringLiteral("live")).toBool())
            continue;
        live += 1;
        if (liveModel.isEmpty())
            liveModel = provider.value(QStringLiteral("model")).toString();
    }
    state.insert(QStringLiteral("providers"), static_cast<int>(providers.size()));
    state.insert(QStringLiteral("liveProviders"), live);
    if (!liveModel.isEmpty())
        state.insert(QStringLiteral("model"), liveModel);

    QString hint;
    if (locked)
        hint = QStringLiteral("The Xenia identity is locked. Unlock it from the assistant panel.");
    else if (!initialized)
        hint = QStringLiteral("Xenia has no identity yet. Create one from the assistant panel "
                              "before prompts can be sealed to a provider.");
    else if (live == 0)
        hint = QStringLiteral("No live Xenia provider in room '%1'. Start the provider node "
                              "(ollama + logoscore) and keep it running.")
                   .arg(QString::fromLatin1(kXeniaRoomDefault));
    if (!hint.isEmpty())
        state.insert(QStringLiteral("hint"), hint);
    state.insert(QStringLiteral("ready"), initialized && !locked && live > 0);
    return state;
}

QString DhunCommonsBackend::xeniaPromptText(const QJsonArray& messages) const
{
    QStringList parts;
    for (const QJsonValue& value : messages) {
        const QJsonObject entry = value.toObject();
        const QString role = entry.value(QStringLiteral("role")).toString();
        const QString content = entry.value(QStringLiteral("content")).toString().trimmed();
        if (content.isEmpty())
            continue;
        if (role == QStringLiteral("system"))
            parts.append(QStringLiteral("Instructions: ") + content);
        else if (role == QStringLiteral("assistant"))
            parts.append(QStringLiteral("Assistant: ") + content);
        else
            parts.append(QStringLiteral("User: ") + content);
    }
    parts.append(QStringLiteral("Answer the last user message in plain text, under 180 words."));
    QString text = parts.join(QStringLiteral("\n\n"));
    if (text.size() > kMaxXeniaPromptChars) {
        const int tail = kMaxXeniaPromptChars / 3;
        const int head = kMaxXeniaPromptChars - tail - 5;
        text = text.left(head) + QStringLiteral("\n…\n") + text.right(tail);
    }
    return text;
}

QString DhunCommonsBackend::xeniaChat(const QJsonArray& messages, double temperature, int maxTokens)
{
    Q_UNUSED(temperature);
    Q_UNUSED(maxTokens);

    QJsonObject result;
    result.insert(QStringLiteral("provider"), QStringLiteral("xenia"));
    const qint64 startedMs = QDateTime::currentMSecsSinceEpoch();

    const QJsonObject state = xeniaState();
    if (!state.value(QStringLiteral("ready")).toBool()) {
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("configured"), state.value(QStringLiteral("available")).toBool());
        result.insert(QStringLiteral("error"),
                      state.value(QStringLiteral("error")).toString(
                          state.value(QStringLiteral("hint")).toString(
                              QStringLiteral("The Xenia router is not ready."))));
        return jsonCompact(result);
    }

    auto wait = [](int ms) {
        QEventLoop loop;
        QTimer::singleShot(ms, &loop, &QEventLoop::quit);
        loop.exec();
    };

    if (modules().inference.deliveryStatus() == 0)
        modules().inference.startDelivery();
    for (int i = 0; i < 20 && modules().inference.deliveryStatus() != 2; ++i)
        wait(250);
    const int delivery = modules().inference.deliveryStatus();
    result.insert(QStringLiteral("deliveryStatus"), delivery);
    if (delivery != 2) {
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("Xenia delivery did not connect (status %1). Check the "
                                     "Logos delivery node and try again.").arg(delivery));
        return jsonCompact(result);
    }

    QString room = qEnvironmentVariable("DHUN_XENIA_ROOM").trimmed();
    if (room.isEmpty())
        room = QString::fromLatin1(kXeniaRoomDefault);
    if (modules().inference.room() != room)
        modules().inference.joinRoom(room);
    result.insert(QStringLiteral("room"), room);

    const QString promptId = modules().inference.sendPrompt(xeniaPromptText(messages));
    if (promptId.isEmpty()) {
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("Xenia refused the prompt. No live provider answered the "
                                     "room and encryption may be required."));
        return jsonCompact(result);
    }
    result.insert(QStringLiteral("promptId"), promptId);

    const qint64 deadline = QDateTime::currentMSecsSinceEpoch() + kXeniaWaitMs;
    while (QDateTime::currentMSecsSinceEpoch() < deadline) {
        wait(kXeniaPollMs);
        const QJsonArray exchanges =
            QJsonDocument::fromJson(modules().inference.listExchanges().toUtf8()).array();
        for (const QJsonValue& value : exchanges) {
            const QJsonObject exchange = value.toObject();
            if (exchange.value(QStringLiteral("id")).toString() != promptId)
                continue;
            if (exchange.value(QStringLiteral("answered")).toBool()) {
                const QString content = exchange.value(QStringLiteral("text")).toString().trimmed();
                if (content.isEmpty())
                    continue;
                result.insert(QStringLiteral("success"), true);
                result.insert(QStringLiteral("content"), content);
                result.insert(QStringLiteral("model"), exchange.value(QStringLiteral("model")).toString());
                result.insert(QStringLiteral("exchangesProvider"),
                              exchange.value(QStringLiteral("provider")).toString());
                result.insert(QStringLiteral("rttMs"), exchange.value(QStringLiteral("rttMs")).toDouble());
                result.insert(QStringLiteral("sealed"), exchange.value(QStringLiteral("sealed")).toBool());
                result.insert(QStringLiteral("seconds"),
                              (QDateTime::currentMSecsSinceEpoch() - startedMs) / 1000.0);
                return jsonCompact(result);
            }
            if (exchange.value(QStringLiteral("failed")).toBool()) {
                result.insert(QStringLiteral("success"), false);
                QString reason = exchange.value(QStringLiteral("reason")).toString().trimmed();
                if (reason.isEmpty())
                    reason = QStringLiteral("The provider did not answer.");
                result.insert(QStringLiteral("error"), QStringLiteral("Xenia: ") + reason);
                return jsonCompact(result);
            }
            break;
        }
    }

    result.insert(QStringLiteral("success"), false);
    result.insert(QStringLiteral("error"),
                  QStringLiteral("Xenia did not answer within 100 seconds. Check that the "
                                 "provider node is running in room '%1'.").arg(room));
    return jsonCompact(result);
}

QString DhunCommonsBackend::xeniaAccount(QString passphrase)
{
    QJsonObject result;
    result.insert(QStringLiteral("provider"), QStringLiteral("xenia"));
    if (!m_contextReady)
        return jsonCompact(failureObject(QStringLiteral("The module backend is not ready inside Basecamp.")));

    const QJsonObject before =
        QJsonDocument::fromJson(modules().inference.identityStatus().toUtf8()).object();
    if (before.isEmpty()) {
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("The Xenia inference module is not installed. Install the "
                                     "inference LGX in Basecamp and reopen Dhun Commons."));
        return jsonCompact(result);
    }
    if (before.value(QStringLiteral("locked")).toBool()) {
        if (passphrase.trimmed().isEmpty()) {
            result.insert(QStringLiteral("success"), false);
            result.insert(QStringLiteral("locked"), true);
            result.insert(QStringLiteral("error"),
                          QStringLiteral("The Xenia identity is locked. Enter its passphrase to "
                                         "unlock it."));
            return jsonCompact(result);
        }
        const bool unlocked = modules().inference.unlock(passphrase);
        const QJsonObject afterUnlock =
            QJsonDocument::fromJson(modules().inference.identityStatus().toUtf8()).object();
        const bool ok = unlocked && afterUnlock.value(QStringLiteral("initialized")).toBool();
        result.insert(QStringLiteral("success"), ok);
        result.insert(QStringLiteral("created"), false);
        result.insert(QStringLiteral("unlocked"), ok);
        if (!ok) {
            result.insert(QStringLiteral("error"),
                          QStringLiteral("Xenia could not unlock the identity. Check the "
                                         "passphrase and try again."));
            return jsonCompact(result);
        }
        result.insert(QStringLiteral("fingerprint"),
                      afterUnlock.value(QStringLiteral("fingerprint")).toString());
        result.insert(QStringLiteral("note"), QStringLiteral("The Xenia identity is unlocked."));
        return jsonCompact(result);
    }
    if (before.value(QStringLiteral("initialized")).toBool()) {
        result.insert(QStringLiteral("success"), true);
        result.insert(QStringLiteral("created"), false);
        result.insert(QStringLiteral("fingerprint"),
                      before.value(QStringLiteral("fingerprint")).toString());
        result.insert(QStringLiteral("note"), QStringLiteral("A Xenia identity already exists."));
        return jsonCompact(result);
    }

    const QString mnemonic = modules().inference.createAccount(passphrase);
    const QJsonObject after =
        QJsonDocument::fromJson(modules().inference.identityStatus().toUtf8()).object();
    const bool initialized = after.value(QStringLiteral("initialized")).toBool();
    result.insert(QStringLiteral("success"), initialized);
    result.insert(QStringLiteral("created"), initialized);
    if (!initialized) {
        result.insert(QStringLiteral("error"),
                      QStringLiteral("Xenia could not create an identity. Check the Xenia "
                                     "inference module and try again."));
        return jsonCompact(result);
    }
    result.insert(QStringLiteral("fingerprint"),
                  after.value(QStringLiteral("fingerprint")).toString());
    if (!mnemonic.trimmed().isEmpty()) {
        result.insert(QStringLiteral("mnemonic"), mnemonic.trimmed());
        result.insert(QStringLiteral("warning"),
                      QStringLiteral("Write this seed phrase down now. It is shown once and is "
                                     "never stored by Dhun Commons."));
    } else {
        result.insert(QStringLiteral("note"),
                      QStringLiteral("Xenia created a seed-file identity (no mnemonic exists)."));
    }
    return jsonCompact(result);
}

QString DhunCommonsBackend::aiChat(QString requestJson)
{
    const QJsonObject request = QJsonDocument::fromJson(requestJson.toUtf8()).object();
    if (request.isEmpty())
        return jsonCompact(failureObject(QStringLiteral("The assistant request was not valid JSON.")));
    if (request.contains(QStringLiteral("success")) && !request.value(QStringLiteral("success")).toBool(true))
        return jsonCompact(failureObject(QStringLiteral("The assistant request was empty.")));

    const QJsonArray incoming = request.value(QStringLiteral("messages")).toArray();
    if (incoming.isEmpty())
        return jsonCompact(failureObject(QStringLiteral("The assistant request had no messages.")));

    QJsonArray messages;
    int totalChars = 0;
    for (const QJsonValue& value : incoming) {
        if (messages.size() >= kMaxAiMessages)
            break;
        const QJsonObject entry = value.toObject();
        QString role = entry.value(QStringLiteral("role")).toString().trimmed().toLower();
        if (role != QStringLiteral("system") && role != QStringLiteral("assistant"))
            role = QStringLiteral("user");
        QString content = entry.value(QStringLiteral("content")).toString();
        if (content.trimmed().isEmpty())
            continue;
        totalChars += content.size();
        if (totalChars > kMaxAiPromptChars)
            return jsonCompact(failureObject(
                QStringLiteral("The conversation is too long for one request. Start a new thread or "
                               "shorten the pasted text.")));
        QJsonObject clean;
        clean.insert(QStringLiteral("role"), role);
        clean.insert(QStringLiteral("content"), content);
        messages.append(clean);
    }
    if (messages.isEmpty())
        return jsonCompact(failureObject(QStringLiteral("The assistant request had no usable messages.")));

    double temperature = request.value(QStringLiteral("temperature")).toDouble(0.2);
    temperature = qBound(0.0, temperature, 2.0);
    int maxTokens = request.value(QStringLiteral("maxTokens")).toInt(900);
    maxTokens = qBound(64, maxTokens, 4096);

    const QString requestedProvider = request.value(QStringLiteral("provider")).toString().trimmed().toLower();
    const bool localOnly = request.value(QStringLiteral("localOnly")).toBool(false);
    if (!localOnly && requestedProvider != QStringLiteral("openrouter")
        && requestedProvider != QStringLiteral("ollama")) {
        const QJsonObject xenia = xeniaState();
        if (xenia.value(QStringLiteral("ready")).toBool())
            return xeniaChat(messages, temperature, maxTokens);
    }

    const QJsonObject local = localModelInfo();
    if (local.value(QStringLiteral("success")).toBool()) {
        const QString localModel = local.value(QStringLiteral("model")).toString();
        QJsonObject localPayload;
        localPayload.insert(QStringLiteral("model"), localModel);
        localPayload.insert(QStringLiteral("messages"), messages);
        localPayload.insert(QStringLiteral("temperature"), temperature);
        localPayload.insert(QStringLiteral("max_tokens"), maxTokens);
        localPayload.insert(QStringLiteral("stream"), false);
        return localAssistantChat(localPayload, localModel, local.value(QStringLiteral("endpoint")).toString());
    }

    if (request.value(QStringLiteral("localOnly")).toBool(false)) {
        QJsonObject result = failureObject(
            QStringLiteral("The local Ollama model is unavailable. Kitchen did not contact a remote provider; start Ollama and retry, or use the built-in planner."));
        result.insert(QStringLiteral("provider"), QStringLiteral("ollama"));
        result.insert(QStringLiteral("configured"), false);
        return jsonCompact(result);
    }

    const AiConfig cfg = aiConfig();
    if (cfg.key.isEmpty()) {
        QJsonObject result = failureObject(
            QStringLiteral("No local model responded and no OpenRouter key is configured. Start a loopback model, or configure OpenRouter for remote inference."));
        result.insert(QStringLiteral("configured"), false);
        result.insert(QStringLiteral("configPath"), cfg.configPath);
        return jsonCompact(result);
    }

    QString model = request.value(QStringLiteral("model")).toString().trimmed();
    if (model.isEmpty())
        model = cfg.model;
    static const QRegularExpression modelRe(QStringLiteral("^[A-Za-z0-9._:/-]{2,96}$"));
    if (!modelRe.match(model).hasMatch())
        return jsonCompact(failureObject(QStringLiteral("That model name is not a valid OpenRouter model id.")));

    QJsonObject payload;
    payload.insert(QStringLiteral("model"), model);
    payload.insert(QStringLiteral("messages"), messages);
    payload.insert(QStringLiteral("temperature"), temperature);
    payload.insert(QStringLiteral("max_tokens"), maxTokens);

    QNetworkAccessManager network;
    QNetworkRequest httpRequest{QUrl(QString::fromLatin1(kOpenRouterUrl))};
    httpRequest.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    httpRequest.setRawHeader("Authorization", QByteArray("Bearer ") + cfg.key.toUtf8());
    httpRequest.setRawHeader("HTTP-Referer", cfg.referer.toUtf8());
    httpRequest.setRawHeader("X-Title", cfg.title.toUtf8());
    httpRequest.setTransferTimeout(55000);

    const qint64 startedMs = QDateTime::currentMSecsSinceEpoch();
    QNetworkReply* reply = network.post(httpRequest, QJsonDocument(payload).toJson(QJsonDocument::Compact));

    QEventLoop loop;
    QTimer guard;
    guard.setSingleShot(true);
    QObject::connect(&guard, &QTimer::timeout, &loop, &QEventLoop::quit);
    QObject::connect(reply, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    guard.start(60000);
    loop.exec();
    guard.stop();

    QJsonObject result;
    result.insert(QStringLiteral("model"), model);
    result.insert(QStringLiteral("provider"), QStringLiteral("openrouter"));
    result.insert(QStringLiteral("seconds"),
                  (QDateTime::currentMSecsSinceEpoch() - startedMs) / 1000.0);

    if (!reply->isFinished()) {
        reply->abort();
        reply->deleteLater();
        result = failureObject(QStringLiteral("OpenRouter did not answer within 60 seconds."));
        result.insert(QStringLiteral("model"), model);
        return jsonCompact(result);
    }

    const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
    const QByteArray body = reply->readAll();
    QString networkError = reply->errorString();
    const bool transportFailed = reply->error() != QNetworkReply::NoError && status == 0;
    reply->deleteLater();

    networkError = redactSecret(networkError, cfg.key);
    result.insert(QStringLiteral("httpStatus"), status);

    if (transportFailed) {
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("OpenRouter could not be reached: ") + networkError);
        return jsonCompact(result);
    }

    const QJsonObject parsed = QJsonDocument::fromJson(body).object();
    if (status < 200 || status >= 300) {
        QString detail = parsed.value(QStringLiteral("error")).toObject()
                             .value(QStringLiteral("message")).toString().trimmed();
        if (detail.isEmpty())
            detail = QString::fromUtf8(body).left(300).trimmed();
        detail = redactSecret(detail, cfg.key);
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("OpenRouter returned HTTP ") + QString::number(status)
                          + (detail.isEmpty() ? QString() : QStringLiteral(": ") + detail));
        return jsonCompact(result);
    }

    const QJsonArray choices = parsed.value(QStringLiteral("choices")).toArray();
    QString content;
    if (!choices.isEmpty()) {
        const QJsonValue value = choices.first().toObject()
                                     .value(QStringLiteral("message")).toObject()
                                     .value(QStringLiteral("content"));
        if (value.isString()) {
            content = value.toString();
        } else if (value.isArray()) {
            QStringList parts;
            for (const QJsonValue& part : value.toArray()) {
                const QString text = part.toObject().value(QStringLiteral("text")).toString();
                if (!text.isEmpty())
                    parts.append(text);
            }
            content = parts.join(QLatin1Char(' '));
        }
    }

    if (content.trimmed().isEmpty()) {
        result.insert(QStringLiteral("success"), false);
        result.insert(QStringLiteral("error"),
                      QStringLiteral("OpenRouter returned no text. Check the model id and try again."));
        return jsonCompact(result);
    }

    const QString servedModel = parsed.value(QStringLiteral("model")).toString().trimmed();
    if (!servedModel.isEmpty())
        result.insert(QStringLiteral("model"), servedModel);
    const QJsonObject usage = parsed.value(QStringLiteral("usage")).toObject();
    if (!usage.isEmpty())
        result.insert(QStringLiteral("usage"), usage);
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("content"), content);
    return jsonCompact(result);
}

QString DhunCommonsBackend::readTextFile(QString path)
{
    QString resolved = path.trimmed();
    if (resolved.startsWith(QStringLiteral("file://")))
        resolved = QUrl(resolved).toLocalFile();
    if (resolved.isEmpty())
        return jsonCompact(failureObject(QStringLiteral("No file was chosen.")));

    const QFileInfo info(resolved);
    if (!info.exists() || !info.isFile())
        return jsonCompact(failureObject(QStringLiteral("The chosen file could not be found.")));

    const QString suffix = info.suffix().toLower();
    if (suffix == QStringLiteral("pdf") || suffix == QStringLiteral("doc")
        || suffix == QStringLiteral("docx") || suffix == QStringLiteral("pages")) {
        return jsonCompact(failureObject(
            QStringLiteral("This module does not extract PDF or Word text. Export the document as "
                           ".txt or .md, or paste the background into the profile field.")));
    }
    static const QSet<QString> allowed{QStringLiteral("txt"), QStringLiteral("md"),
                                       QStringLiteral("markdown"), QStringLiteral("csv"),
                                       QStringLiteral("json"), QStringLiteral("text")};
    if (!allowed.contains(suffix)) {
        return jsonCompact(failureObject(
            QStringLiteral("Only plain-text files (.txt, .md, .csv, .json) can be read. Convert "
                           "other formats or paste the text.")));
    }
    if (info.size() > kMaxTextFileBytes) {
        return jsonCompact(failureObject(
            QStringLiteral("The file is larger than 256 KB. Trim it or paste the relevant part.")));
    }

    QFile file(resolved);
    if (!file.open(QIODevice::ReadOnly))
        return jsonCompact(failureObject(QStringLiteral("The chosen file could not be opened.")));
    const QByteArray bytes = file.readAll();
    file.close();
    if (bytes.isEmpty())
        return jsonCompact(failureObject(QStringLiteral("The chosen file is empty.")));
    if (bytes.contains('\0'))
        return jsonCompact(failureObject(QStringLiteral("The chosen file is not plain UTF-8 text.")));

    QString text = QString::fromUtf8(bytes);
    const bool truncated = text.size() > kMaxTextChars;
    if (truncated)
        text = text.left(kMaxTextChars);

    QJsonObject result;
    result.insert(QStringLiteral("success"), true);
    result.insert(QStringLiteral("name"), info.fileName());
    result.insert(QStringLiteral("characters"), text.size());
    result.insert(QStringLiteral("bytes"), static_cast<double>(bytes.size()));
    result.insert(QStringLiteral("truncated"), truncated);
    result.insert(QStringLiteral("text"), text);
    return jsonCompact(result);
}
