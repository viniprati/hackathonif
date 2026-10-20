import 'package:flutter/material.dart';
import '../data/notifications.dart';
import 'theme.dart';

class NotificationsPanel extends StatelessWidget {
  const NotificationsPanel({super.key, required this.center});
  final NotificationCenter center;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
      listenable: center,
      builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Avisos de montantes'),
                  subtitle: const Text(
                      'Consultar novos cadastros e conclusões enquanto o app estiver aberto.'),
                  value: center.enabled,
                  onChanged: center.loaded && !center.saving
                      ? center.setEnabled
                      : null),
              SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Receber com o app fechado'),
                  subtitle: Text(center.push?.available == true
                      ? 'O Android pedirá permissão. Funciona após a sincronização no servidor.'
                      : 'Disponível no Android após configurar o Firebase e gerar um novo APK.'),
                  value: center.pushEnabled,
                  onChanged: center.loaded &&
                          !center.saving &&
                          center.push?.available == true
                      ? center.setPushEnabled
                      : null),
              const Text(
                  'Os avisos são compartilhados após sincronizar no Perfil. Concluído significa que todos os alimentos tiveram seu rateio finalizado, sem comprovar a entrega física.'),
              if (center.error != null) ...[
                GuidanceMessage(center.error!),
                if (!center.loaded)
                  OutlinedButton(
                      onPressed: center.saving ? null : center.initialize,
                      child: const Text('Tentar novamente')),
              ],
              if (center.busy)
                const LinearProgressIndicator(
                    semanticsLabel: 'Buscando avisos'),
              ...[
                Wrap(spacing: 8, children: [
                  OutlinedButton.icon(
                      onPressed: center.busy
                          ? null
                          : () => center.refresh(force: true),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Atualizar avisos')),
                  TextButton(
                      onPressed: center.saving || center.unread == 0
                          ? null
                          : center.markRead,
                      child: const Text('Marcar como lidos'))
                ]),
                if (center.notices.isEmpty &&
                    !center.busy &&
                    center.error == null)
                  const Text('Nenhum aviso disponível.'),
                const Text(
                    'Até 50 avisos mais recentes. A leitura é salva somente neste aparelho.'),
                for (final notice in center.notices)
                  Card(
                      child: ListTile(
                          leading: ExcludeSemantics(
                              child: Icon(notice.completed
                                  ? Icons.task_alt
                                  : Icons.add_circle_outline)),
                          title: Text('${notice.title}: ${notice.name}'),
                          subtitle: Text(
                              '${formatDate(notice.createdAt)} às ${notice.createdAt.hour.toString().padLeft(2, '0')}:${notice.createdAt.minute.toString().padLeft(2, '0')} • ${center.isRead(notice) ? 'Lido' : 'Não lido'}'))),
              ],
            ],
          ));
}
