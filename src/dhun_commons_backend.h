#pragma once

#include <QString>

#include <QJsonObject>

#include "logos_ui_plugin_context.h"
#include "rep_dhun_commons_source.h"

class DhunCommonsBackend : public DhunCommonsSimpleSource,
                           public LogosUiPluginContext
{
public:
    QString createWallet(QString password) override;
    QString openWallet() override;
    QString refreshChain() override;
    QString sendSettlement(QString fromAccountId,
                           QString toAccountId,
                           QString amount) override;
    QString checkTransaction(QString txHash) override;
    QString chainDetails() override;
    QString publishTelegramState(QString json) override;
    QString telegramInbox() override;
    QString ackTelegramMessage(QString id) override;
    QString readPhotoBase64(QString path) override;
    QString probeModelServer(QString endpoint) override;
    QString startMenuPhoto(QString path, QString endpoint, QString model, QString prompt) override;
    QString aiChat(QString requestJson) override;
    QString aiStatus() override;
    QString readTextFile(QString path) override;

    void onContextReady() override;

private:
    QString baseWalletDirectory();
    QString walletDirectory();
    QString telegramDirectory() const;
    bool ensureTelegramDirectory(QString* error);
    bool ensureWalletDirectory(QString* error);
    bool walletFilesExist() const;
    void writeConfig(const QString& path) const;
    QString loadRoleMapping() const;
    bool saveRoleMapping(const QString& json) const;
    QString accountsPayload(bool* ok);
    void setFailure(const QString& notice, const QString& status = QStringLiteral("error"));
    void autoOpen(int attempt = 0);
    bool moduleReady() const;
    bool readPhotoBytes(const QString& path, QByteArray* bytes, QString* mime, QString* error) const;
    bool loopbackChatUrl(const QString& endpoint, QString* url, QString* error) const;

    struct AiConfig {
        QString key;
        QString model;
        QString source;
        QString configPath;
        QString referer;
        QString title;
        bool insecureFile = false;
    };
    AiConfig aiConfig() const;

    bool m_contextReady = false;
    bool m_walletOpen = false;
    bool m_busy = false;
};
