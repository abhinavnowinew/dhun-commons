#include "dhun_commons_backend.h"

#include "logos_sdk.h"

#include <QDateTime>
#include <QDebug>
#include <QDir>
#include <QEventLoop>
#include <QFile>
#include <QFileInfo>
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

namespace {

const char kSequencer[] = "https://testnet.lez.logos.co";
const char kWalletSubdir[] = "dhun_chain";
const char kRelaySubdir[] = "Logos/LogosBasecamp/dhun_relay";
const char kConfigName[] = "config.json";
const char kStorageName[] = "storage.json";
const char kMappingName[] = "roles.json";
const char kTokenDecimals = 9;
const int kMaxTelegramSnapshot = 256 * 1024;

struct Role {
    const char* key;
    const char* name;
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

void DhunCommonsBackend::finishModelRequest(const QString& state, const QJsonObject& payload)
{
    QJsonObject snapshot = payload;
    snapshot.insert(QStringLiteral("state"), state);
    setModelReply(jsonCompact(snapshot));
    setModelState(state);
}

QString DhunCommonsBackend::startMenuPhoto(QString path,
                                           QString endpoint,
                                           QString model,
                                           QString prompt)
{
    if (m_modelReplyHandle) {
        return jsonCompact(failureObject(QStringLiteral("A menu photo request is already running.")));
    }

    QString chatUrl;
    QString error;
    if (!loopbackChatUrl(endpoint, &chatUrl, &error)) {
        finishModelRequest(QStringLiteral("failed"), failureObject(error));
        return jsonCompact(failureObject(error));
    }

    const QString name = model.trimmed();
    if (name.isEmpty()) {
        const QString message = QStringLiteral("Name the local vision model first (for example qwen2.5vl:3b).");
        finishModelRequest(QStringLiteral("failed"), failureObject(message));
        return jsonCompact(failureObject(message));
    }

    QByteArray bytes;
    QString mime;
    if (!readPhotoBytes(path, &bytes, &mime, &error)) {
        finishModelRequest(QStringLiteral("failed"), failureObject(error));
        return jsonCompact(failureObject(error));
    }

    const QString instruction = prompt.trimmed();
    if (instruction.isEmpty()) {
        const QString message = QStringLiteral("The menu-reading instruction was empty.");
        finishModelRequest(QStringLiteral("failed"), failureObject(message));
        return jsonCompact(failureObject(message));
    }

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
    QJsonArray content;
    content.append(textPart);
    content.append(imagePart);
    QJsonObject message;
    message.insert(QStringLiteral("role"), QStringLiteral("user"));
    message.insert(QStringLiteral("content"), content);
    QJsonArray messages;
    messages.append(message);

    QJsonObject payload;
    payload.insert(QStringLiteral("model"), name);
    payload.insert(QStringLiteral("temperature"), 0);
    payload.insert(QStringLiteral("max_tokens"), 500);
    payload.insert(QStringLiteral("messages"), messages);

    if (!m_modelNetwork)
        m_modelNetwork = new QNetworkAccessManager(this);
    if (!m_modelClock) {
        m_modelClock = new QTimer(this);
        m_modelClock->setSingleShot(true);
        QObject::connect(m_modelClock, &QTimer::timeout, this, [this]() {
            if (!m_modelReplyHandle)
                return;
            m_modelReplyHandle->abort();
        });
    }

    QNetworkRequest request{QUrl(chatUrl)};
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/json"));
    request.setTransferTimeout(185000);

    m_modelStartedMs = QDateTime::currentMSecsSinceEpoch();
    setModelReply(QStringLiteral("{}"));
    setModelState(QStringLiteral("busy"));
    m_modelReplyHandle = m_modelNetwork->post(request, QJsonDocument(payload).toJson(QJsonDocument::Compact));
    m_modelClock->start(190000);

    QObject::connect(m_modelReplyHandle, &QNetworkReply::finished, this, [this, name]() {
        QNetworkReply* reply = m_modelReplyHandle;
        if (!reply)
            return;
        m_modelReplyHandle = nullptr;
        if (m_modelClock)
            m_modelClock->stop();

        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QByteArray body = reply->readAll();
        const QString networkError = reply->errorString();
        const bool transportFailed = reply->error() != QNetworkReply::NoError && status == 0;
        reply->deleteLater();

        QJsonObject result;
        result.insert(QStringLiteral("httpStatus"), status);
        result.insert(QStringLiteral("model"), name);
        result.insert(QStringLiteral("seconds"),
                      (QDateTime::currentMSecsSinceEpoch() - m_modelStartedMs) / 1000.0);

        if (transportFailed) {
            const bool timedOut = networkError.contains(QStringLiteral("timed out"), Qt::CaseInsensitive)
                || networkError.contains(QStringLiteral("Operation canceled"), Qt::CaseInsensitive);
            result.insert(QStringLiteral("error"),
                          timedOut
                              ? QStringLiteral("The local model did not answer in time. It may still be loading the image.")
                              : QStringLiteral("The local model server did not answer: ") + networkError);
            finishModelRequest(QStringLiteral("failed"), result);
            return;
        }

        if (status < 200 || status >= 300) {
            QString detail = QString::fromUtf8(body).left(300).trimmed();
            if (detail.isEmpty())
                detail = networkError;
            result.insert(QStringLiteral("error"),
                          QStringLiteral("The local model returned HTTP ") + QString::number(status)
                              + (detail.isEmpty() ? QString() : QStringLiteral(": ") + detail));
            finishModelRequest(QStringLiteral("failed"), result);
            return;
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
            result.insert(QStringLiteral("error"),
                          QStringLiteral("The local model returned no text. Check the model name and try again."));
            finishModelRequest(QStringLiteral("failed"), result);
            return;
        }

        const QJsonObject usage = parsed.value(QStringLiteral("usage")).toObject();
        if (!usage.isEmpty())
            result.insert(QStringLiteral("usage"), usage);
        result.insert(QStringLiteral("content"), content);
        finishModelRequest(QStringLiteral("done"), result);
    });

    QJsonObject started;
    started.insert(QStringLiteral("success"), true);
    started.insert(QStringLiteral("url"), chatUrl);
    return jsonCompact(started);
}
