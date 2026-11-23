import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/strings.dart';
import '../../data/api_client.dart';
import '../../domain/models.dart';
import '../common.dart';
import '../live/live_screen.dart';

String _apiError(S s, ApiException e) => switch (e.code) {
      'no_church_plan' => s.t('no_church_plan'),
      'user_not_found' => s.t('member_not_found'),
      'church_mode_disabled' => s.t('join_disabled'),
      _ => errorMessage(s, e.isNetwork ? 'network' : e.code),
    };

/// Declaración obligatoria del organizador: autorización para transmitir el audio.
Future<bool> _attest(BuildContext context) async {
  final s = S.of(context);
  var checked = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text(s.t('attest_title')),
        content: CheckboxListTile(
          value: checked,
          onChanged: (v) => set(() => checked = v ?? false),
          title: Text(s.t('attest_text')),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: checked ? () => Navigator.pop(c, true) : null, child: Text(s.t('confirm'))),
        ],
      ),
    ),
  );
  return ok ?? false;
}

class OrgsScreen extends StatefulWidget {
  const OrgsScreen({super.key});
  @override
  State<OrgsScreen> createState() => _OrgsScreenState();
}

class _OrgsScreenState extends State<OrgsScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _future = context.read<ApiClient>().orgs());

  Future<void> _create() async {
    final s = S.of(context);
    final name = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(s.t('create_org')),
        content: TextField(controller: name, maxLength: 120, decoration: InputDecoration(labelText: s.t('org_name'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('continue'))),
        ],
      ),
    );
    if (ok != true || name.text.trim().length < 2 || !mounted) return;
    if (!await _attest(context) || !mounted) return;
    try {
      await context.read<ApiClient>().createOrg(name.text.trim());
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, _apiError(s, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.t('orgs_title'))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.add), label: Text(s.t('create_org'))),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Center(child: TextButton(onPressed: _load, child: Text(s.t('retry'))));
          final orgs = (snap.data!['orgs'] as List).cast<Map<String, dynamic>>();
          if (orgs.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(s.t('orgs_empty'), textAlign: TextAlign.center)));
          return ListView(children: [
            for (final o in orgs)
              ListTile(
                leading: const Icon(Icons.church_outlined),
                title: Text(o['name'] as String),
                subtitle: Text(s.t('role_${o['role']}')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => OrgDetailScreen(orgId: o['id'] as String)));
                  _load();
                },
              ),
          ]);
        },
      ),
    );
  }
}

class OrgDetailScreen extends StatefulWidget {
  const OrgDetailScreen({super.key, required this.orgId});
  final String orgId;
  @override
  State<OrgDetailScreen> createState() => _OrgDetailScreenState();
}

class _OrgDetailScreenState extends State<OrgDetailScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _future = context.read<ApiClient>().org(widget.orgId));

  Future<void> _newSession() async {
    final s = S.of(context);
    var source = Lang.en;
    var translate = true;
    var save = false;
    var max = 30.0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(s.t('new_session')),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.t('speaker_language')),
              SegmentedButton<Lang>(
                segments: [ButtonSegment(value: Lang.en, label: Text(s.t('english'))), ButtonSegment(value: Lang.es, label: Text(s.t('spanish')))],
                selected: {source},
                onSelectionChanged: (v) => set(() => source = v.first),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: translate,
                onChanged: (v) => set(() => translate = v),
                title: Text('${s.t('translate_to')}: ${source.other == Lang.en ? s.t('english') : s.t('spanish')}'),
              ),
              Text('${s.t('max_listeners')}: ${max.round()}'),
              Slider(value: max, min: 1, max: 30, divisions: 29, label: '${max.round()}', onChanged: (v) => set(() => max = v)),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: save,
                onChanged: (v) => set(() => save = v),
                title: Text(s.t('save_transcript')),
                subtitle: Text(s.t('church_save_desc')),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('continue'))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    if (!await _attest(context) || !mounted) return;
    try {
      final r = await context.read<ApiClient>().createChurchSession(widget.orgId, source: source, target: translate ? source.other : null, maxListeners: max.round(), save: save);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => SessionCodeScreen(orgId: widget.orgId, session: r, source: source, target: translate ? source.other : null),
      ));
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, _apiError(s, e));
    }
  }

  Future<void> _addMember() async {
    final s = S.of(context);
    final email = TextEditingController();
    var role = 'member';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(s.t('add_member')),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: s.t('member_email'))),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: [ButtonSegment(value: 'member', label: Text(s.t('role_member'))), ButtonSegment(value: 'admin', label: Text(s.t('role_admin')))],
              selected: {role},
              onSelectionChanged: (v) => set(() => role = v.first),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(s.t('cancel'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(s.t('confirm'))),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<ApiClient>().addMember(widget.orgId, email.text.trim(), role);
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, _apiError(s, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        final d = snap.data;
        final canManage = d != null && d['role'] != 'member';
        return Scaffold(
          appBar: AppBar(title: Text(d?['name'] as String? ?? s.t('church_title'))),
          floatingActionButton: canManage ? FloatingActionButton.extended(onPressed: _newSession, icon: const Icon(Icons.add), label: Text(s.t('new_session'))) : null,
          body: snap.connectionState != ConnectionState.done
              ? const Center(child: CircularProgressIndicator())
              : snap.hasError
                  ? Center(child: TextButton(onPressed: _load, child: Text(s.t('retry'))))
                  : RefreshIndicator(
                      onRefresh: () async => _load(),
                      child: ListView(padding: const EdgeInsets.all(16), children: [
                        SectionTitle(s.t('org_sessions')),
                        for (final ses in (d!['sessions'] as List).cast<Map<String, dynamic>>())
                          ListTile(
                            leading: Icon(ses['status'] == 'live' ? Icons.podcasts : Icons.event_outlined),
                            title: Text(DateFormat.yMMMd(s.code).add_jm().format(DateTime.parse(ses['createdAt'] as String).toLocal())),
                            subtitle: Text('${s.t('session_${ses['status']}')} · ${(ses['sourceLang'] as String).toUpperCase()}'
                                '${ses['targetLang'] == null ? '' : ' → ${(ses['targetLang'] as String).toUpperCase()}'} · ${s.t('listeners_count')}: ${ses['listeners']}'),
                            trailing: canManage && ses['status'] != 'ended'
                                ? TextButton(
                                    onPressed: () => Navigator.of(context)
                                        .push(MaterialPageRoute<void>(
                                          builder: (_) => SessionCodeScreen(
                                            orgId: widget.orgId,
                                            session: ses,
                                            source: Lang.parse(ses['sourceLang'] as String),
                                            target: ses['targetLang'] == null ? null : Lang.parse(ses['targetLang'] as String),
                                          ),
                                        ))
                                        .then((_) => _load()),
                                    child: Text(s.t('reopen_broadcast')),
                                  )
                                : null,
                          ),
                        if ((d['usage'] as List).isNotEmpty) ...[
                          SectionTitle(s.t('usage_title')),
                          Builder(builder: (_) {
                            final u = (d['usage'] as List).first as Map<String, dynamic>;
                            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text('${s.t('usage_broadcast')}: ${formatMinutes((u['broadcastSeconds'] as num).toInt())}'),
                              Text('${s.t('usage_peak')}: ${u['peakListeners']}'),
                            ]);
                          }),
                        ],
                        if (canManage) ...[
                          SectionTitle(s.t('members')),
                          for (final m in (d['members'] as List).cast<Map<String, dynamic>>())
                            ListTile(
                              title: Text(m['email'] as String? ?? ''),
                              subtitle: Text(s.t('role_${m['role']}')),
                              trailing: m['role'] == 'owner'
                                  ? null
                                  : IconButton(
                                      tooltip: s.t('delete'),
                                      icon: const Icon(Icons.person_remove_outlined),
                                      onPressed: () async {
                                        await context.read<ApiClient>().removeMember(widget.orgId, m['userId'] as String);
                                        _load();
                                      },
                                    ),
                            ),
                          TextButton.icon(onPressed: _addMember, icon: const Icon(Icons.person_add_alt), label: Text(s.t('add_member'))),
                        ],
                        const SizedBox(height: 80),
                      ]),
                    ),
        );
      },
    );
  }
}

/// Muestra el código y el QR (solo al crear la sesión) y permite transmitir.
class SessionCodeScreen extends StatelessWidget {
  const SessionCodeScreen({super.key, required this.orgId, required this.session, required this.source, required this.target});
  final String orgId;
  final Map<String, dynamic> session;
  final Lang source;
  final Lang? target;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final code = session['code'] as String?;
    final qr = session['qr'] as String?;
    final expires = DateTime.tryParse('${session['joinExpiresAt']}')?.toLocal();
    return Scaffold(
      appBar: AppBar(title: Text(s.t('session_code_title'))),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        if (code != null && qr != null) ...[
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: QrImageView(data: qr, size: 240, backgroundColor: Colors.white, semanticsLabel: code),
            ),
          ),
          const SizedBox(height: 16),
          Center(child: SelectableText(code, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, letterSpacing: 6))),
          const SizedBox(height: 8),
          Text('${s.t('session_code_help')} ${expires == null ? '' : DateFormat.yMMMd(s.code).add_jm().format(expires)}', textAlign: TextAlign.center),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.podcasts),
          label: Text(s.t('start_broadcast')),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => LiveScreen(
              source: source,
              display: target == null ? DisplayMode.original : DisplayMode.both,
              save: false,
              churchSessionId: session['id'] as String,
            ),
          )),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () async {
            if (!await confirmDialog(context, s.t('end_session_confirm'), confirmLabel: s.t('end_session'), destructive: true)) return;
            if (!context.mounted) return;
            try {
              await context.read<ApiClient>().endChurchSession(orgId, session['id'] as String);
              if (context.mounted) Navigator.of(context).pop();
            } on ApiException catch (e) {
              if (context.mounted) showSnack(context, _apiError(s, e));
            }
          },
          child: Text(s.t('end_session')),
        ),
      ]),
    );
  }
}
