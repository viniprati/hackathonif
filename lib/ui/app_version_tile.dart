import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppVersionTile extends StatefulWidget {
  const AppVersionTile({super.key});

  @override
  State<AppVersionTile> createState() => _AppVersionTileState();
}

class _AppVersionTileState extends State<AppVersionTile> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: _info,
        builder: (context, snapshot) {
          final info = snapshot.data;
          return ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Versão'),
            subtitle: Text(info != null
                ? 'Versão ${info.version} (${info.buildNumber})'
                : snapshot.hasError
                    ? 'Versão indisponível'
                    : 'Consultando versão…'),
          );
        },
      );
}
