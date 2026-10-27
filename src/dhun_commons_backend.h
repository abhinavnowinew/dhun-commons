#pragma once

#include <QPointer>
#include <QString>

#include <QJsonObject>

#include "logos_ui_plugin_context.h"
#include "rep_dhun_commons_source.h"

class QNetworkAccessManager;
class QNetworkReply;
class QTimer;

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
    void finishModelRequest(const QString& state, const QJsonObject& payload);

    bool m_contextReady = false;
    bool m_walletOpen = false;
    bool m_busy = false;
    QNetworkAccessManager* m_modelNetwork = nullptr;
    QPointer<QNetworkReply> m_modelReplyHandle;
    QTimer* m_modelClock = nullptr;
    qint64 m_modelStartedMs = 0;
};
