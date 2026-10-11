import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/jef_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final session = JefSession();
  runApp(JefApp(session: session));
  unawaited(session.start());
}

class JefApp extends StatelessWidget {
  const JefApp({super.key, required this.session});
  final JefSession session;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jef Service',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: jefPrimary,
          primary: jefPrimary,
          secondary: jefOrange,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: const Color(0xFFF6FAF9),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF6FAF9),
          centerTitle: false,
          foregroundColor: jefDark,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 17,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFD8EAE7)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: jefPrimary,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(54),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            textStyle: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: !session.ready
          ? const JefSplash()
          : session.startupError != null
          ? JefStartupError(session: session)
          : !session.loggedIn
          ? AuthPage(session: session)
          : Shell(session: session),
    ),
  );
}

class JefSplash extends StatelessWidget {
  const JefSplash({super.key});
  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: jefDark,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.handyman_rounded, color: Colors.white, size: 74),
          SizedBox(height: 16),
          Text(
            'jefservice',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 34,
            ),
          ),
          SizedBox(height: 28),
          CircularProgressIndicator(color: jefOrange),
        ],
      ),
    ),
  );
}

class JefStartupError extends StatelessWidget {
  const JefStartupError({super.key, required this.session});
  final JefSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 72, color: jefPrimary),
              const SizedBox(height: 22),
              const Text(
                'Connexion au serveur indisponible',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: jefDark,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                session.startupError ?? 'Veuillez réessayer.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: session.start,
                child: const Text('Réessayer'),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: session.logout,
                child: const Text('Changer de compte'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget jefTitle(String title, {String? subtitle}) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      title,
      style: const TextStyle(
        fontSize: 25,
        color: jefDark,
        fontWeight: FontWeight.w900,
      ),
    ),
    if (subtitle != null) ...[
      const SizedBox(height: 5),
      Text(
        subtitle,
        style: const TextStyle(color: Color(0xFF617E79), fontSize: 13),
      ),
    ],
  ],
);

Widget jefCard({required Widget child, EdgeInsets? padding}) => Container(
  padding: padding ?? const EdgeInsets.all(18),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(22),
    border: Border.all(color: const Color(0xFFE0EEEB)),
    boxShadow: [
      BoxShadow(
        color: jefDark.withValues(alpha: 0.035),
        blurRadius: 18,
        offset: const Offset(0, 7),
      ),
    ],
  ),
  child: child,
);

Widget jefPill(String text, {Color color = jefPrimary}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.10),
    borderRadius: BorderRadius.circular(50),
  ),
  child: Text(
    text,
    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
  ),
);

void jefError(BuildContext context, Object error) {
  final message = error is JefError
      ? error.message
      : 'Une erreur est survenue.';
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.session});
  final JefSession session;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  bool professional = false,
      registration = false,
      verifying = false,
      busy = false;
  DateTime? lastOtpRequest;
  final phone = TextEditingController(), otp = TextEditingController();
  final first = TextEditingController(), last = TextEditingController();
  final minPrice = TextEditingController(), maxPrice = TextEditingController();
  double? latitude, longitude;
  @override
  void dispose() {
    for (final c in [phone, otp, first, last, minPrice, maxPrice]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submitPhone() async {
    if (lastOtpRequest != null &&
        DateTime.now().difference(lastOtpRequest!).inSeconds < 45) {
      jefError(
        context,
        const JefError('Veuillez patienter 45 secondes avant un nouvel envoi.'),
      );
      return;
    }
    if (!RegExp(r'^\d{9,15}$').hasMatch(phone.text.trim())) {
      jefError(
        context,
        const JefError('Saisissez un numéro entre 9 et 15 chiffres.'),
      );
      return;
    }
    if (registration) {
      final mini = double.tryParse(minPrice.text.replaceAll(',', '.'));
      final maxi = double.tryParse(maxPrice.text.replaceAll(',', '.'));
      if (first.text.trim().isEmpty ||
          last.text.trim().isEmpty ||
          mini == null ||
          maxi == null ||
          !mini.isFinite ||
          !maxi.isFinite ||
          mini < 0 ||
          maxi < mini) {
        jefError(
          context,
          const JefError('Vérifiez le nom et les tarifs minimum/maximum.'),
        );
        return;
      }
    }
    setState(() => busy = true);
    try {
      final point = await jefPosition();
      latitude = point.latitude;
      longitude = point.longitude;
      await widget.session.api.sendOtp(
        phone.text.trim(),
        professional: professional,
        registration: registration,
        latitude: latitude!,
        longitude: longitude!,
      );
      lastOtpRequest = DateTime.now();
      if (!mounted) return;
      setState(() => verifying = true);
    } catch (e) {
      if (mounted) jefError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> submitOtp() async {
    if (!RegExp(r'^\d{4}$').hasMatch(otp.text)) {
      jefError(
        context,
        const JefError('Le code OTP contient quatre chiffres.'),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final data = await widget.session.api.checkOtp(
        phone.text.trim(),
        otp.text,
        professional: professional,
        latitude: latitude!,
        longitude: longitude!,
        registration: registration
            ? {
                'prenom': first.text.trim(),
                'nom': last.text.trim(),
                'tarifMin': double.parse(minPrice.text.replaceAll(',', '.')),
                'tarifMax': double.parse(maxPrice.text.replaceAll(',', '.')),
              }
            : null,
      );
      final token = jefText(data['token']);
      if (token.isEmpty)
        throw const JefError('Aucun token transmis par le serveur.');
      await widget.session.signIn(
        token,
        professional ? JefRole.technician : JefRole.client,
      );
    } catch (e) {
      if (mounted) jefError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 23, vertical: 26),
        children: [
          const SizedBox(height: 16),
          Container(
            height: 174,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [jefPrimary, jefDark]),
              borderRadius: BorderRadius.circular(30),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.handyman_rounded, color: Colors.white, size: 58),
                SizedBox(height: 10),
                Text(
                  'jefservice',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 32,
                  ),
                ),
                Text(
                  'Le bon professionnel, au bon moment',
                  style: TextStyle(color: jefPale, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          jefTitle(
            verifying ? 'Vérification SMS' : 'Bienvenue !',
            subtitle: verifying
                ? 'Entrez le code reçu au ' + phone.text
                : 'Accédez à vos services en quelques instants.',
          ),
          const SizedBox(height: 24),
          if (!verifying) ...[
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  label: Text('Client'),
                  icon: Icon(Icons.person_outline),
                ),
                ButtonSegment(
                  value: true,
                  label: Text('Technicien'),
                  icon: Icon(Icons.handyman_outlined),
                ),
              ],
              selected: {professional},
              onSelectionChanged: (s) => setState(() {
                professional = s.first;
                registration = false;
              }),
            ),
            if (professional) ...[
              const SizedBox(height: 15),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Connexion')),
                  ButtonSegment(value: true, label: Text('Inscription')),
                ],
                selected: {registration},
                onSelectionChanged: (s) =>
                    setState(() => registration = s.first),
              ),
            ],
            const SizedBox(height: 20),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Téléphone',
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),
            if (registration) ...[
              const SizedBox(height: 12),
              TextField(
                controller: first,
                decoration: const InputDecoration(labelText: 'Prénom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: last,
                decoration: const InputDecoration(labelText: 'Nom'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: minPrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tarif minimum (FCFA)',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: maxPrice,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tarif maximum (FCFA)',
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: busy ? null : submitPhone,
              child: busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Recevoir mon code SMS'),
            ),
          ] else ...[
            TextField(
              controller: otp,
              autofocus: true,
              maxLength: 4,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Code à 4 chiffres',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: busy ? null : submitOtp,
              child: busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Valider et continuer'),
            ),
            TextButton(
              onPressed: busy ? null : submitPhone,
              child: const Text('Renvoyer le code SMS (après 45 s)'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      verifying = false;
                      otp.clear();
                    }),
              child: const Text('Modifier le numéro'),
            ),
          ],
          const SizedBox(height: 22),
          jefCard(
            child: const Row(
              children: [
                Icon(Icons.location_on_outlined, color: jefPrimary),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'La localisation est utilisée pour trouver des services et créer des interventions.',
                    style: TextStyle(fontSize: 12, color: jefDark),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class Shell extends StatefulWidget {
  const Shell({super.key, required this.session});
  final JefSession session;
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;
  final List<bool> visited = [true, false, false, false];

  Widget pageAt(int page, bool professional) {
    if (!visited[page]) return const SizedBox.shrink();
    switch (page) {
      case 0:
        return professional
            ? ProDashboard(session: widget.session)
            : ClientHome(session: widget.session);
      case 1:
        return professional
            ? MissionsPage(session: widget.session)
            : ServicesPage(session: widget.session);
      case 2:
        return professional
            ? DocumentsPage(session: widget.session)
            : MissionsPage(session: widget.session);
      default:
        return ProfilePage(session: widget.session);
    }
  }

  @override
  Widget build(BuildContext context) {
    final professional = widget.session.role == JefRole.technician;
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: index,
          children: List.generate(4, (page) => pageAt(page, professional)),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: jefPale,
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() {
          index = i;
          visited[i] = true;
        }),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(
              professional
                  ? Icons.assignment_outlined
                  : Icons.grid_view_outlined,
            ),
            label: professional ? 'Missions' : 'Services',
          ),
          NavigationDestination(
            icon: Icon(
              professional ? Icons.description_outlined : Icons.history_rounded,
            ),
            label: professional ? 'Documents' : 'Demandes',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class ClientHome extends StatelessWidget {
  const ClientHome({super.key, required this.session});
  final JefSession session;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        'Bonjour, ' + jefText(session.accountData['firstName']).trim(),
        style: const TextStyle(
          fontSize: 15,
          color: jefPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 10),
      jefTitle(
        'Bienvenue chez Jef Service',
        subtitle: 'Trouvez facilement les services dont vous avez besoin.',
      ),
      const SizedBox(height: 22),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [jefPrimary, jefDark]),
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.home_repair_service_rounded, color: jefOrange, size: 36),
            SizedBox(height: 20),
            Text(
              'Des professionnels près de vous',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 23,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Plomberie, électricité, dépannage et bien plus.',
              style: TextStyle(color: jefPale),
            ),
          ],
        ),
      ),
      const SizedBox(height: 26),
      jefTitle(
        'Services disponibles',
        subtitle: 'Catalogue actualisé depuis Jef Service.',
      ),
      const SizedBox(height: 14),
      ServiceCatalogue(session: session),
    ],
  );
}

class ServicesPage extends StatelessWidget {
  const ServicesPage({super.key, required this.session});
  final JefSession session;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      jefTitle(
        'Nos services',
        subtitle: 'Sélectionnez un domaine d’intervention.',
      ),
      const SizedBox(height: 16),
      ServiceCatalogue(session: session),
    ],
  );
}

class ServiceCatalogue extends StatefulWidget {
  const ServiceCatalogue({super.key, required this.session});
  final JefSession session;
  @override
  State<ServiceCatalogue> createState() => _ServiceCatalogueState();
}

class _ServiceCatalogueState extends State<ServiceCatalogue> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() => future = widget.session.api.services();
  @override
  Widget build(BuildContext context) =>
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Padding(
              padding: EdgeInsets.all(36),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (snap.hasError)
            return jefCard(
              child: Column(
                children: [
                  Text(snap.error.toString()),
                  TextButton(
                    onPressed: () => setState(reload),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            );
          final list = snap.data ?? [];
          if (list.isEmpty)
            return jefCard(
              child: const Text('Aucun service disponible actuellement.'),
            );
          return Column(
            children: list
                .map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TechniciansPage(
                            session: widget.session,
                            service: s,
                          ),
                        ),
                      ),
                      child: jefCard(
                        child: Row(
                          children: [
                            Container(
                              height: 54,
                              width: 54,
                              decoration: BoxDecoration(
                                color: jefPale,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(
                                Icons.handyman_outlined,
                                color: jefDark,
                                size: 29,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    jefText(s['nom']),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: jefDark,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (jefText(s['description']).isNotEmpty)
                                    Text(
                                      jefText(s['description']),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF718781),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: jefOrange,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      );
}

class TechniciansPage extends StatefulWidget {
  const TechniciansPage({
    super.key,
    required this.session,
    required this.service,
  });
  final JefSession session;
  final Map<String, dynamic> service;
  @override
  State<TechniciansPage> createState() => _TechniciansPageState();
}

class _TechniciansPageState extends State<TechniciansPage> {
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    final serviceId = jefId(widget.service['id']);
    future = serviceId == null
        ? Future<List<Map<String, dynamic>>>.error(
            const JefError('Service introuvable.'),
          )
        : widget.session.api.technicians(serviceId);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(jefText(widget.service['nom']))),
    body: FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snap.hasError)
          return Center(
            child: TextButton(
              onPressed: () => setState(reload),
              child: Text(snap.error.toString() + ' — Réessayer'),
            ),
          );
        final technicians = snap.data ?? [];
        return ListView(
          padding: const EdgeInsets.all(18),
          children: [
            jefTitle(
              'Professionnels disponibles',
              subtitle: 'Les tarifs sont indicatifs selon chaque profil.',
            ),
            const SizedBox(height: 18),
            if (technicians.isEmpty)
              jefCard(
                child: const Text(
                  'Aucun professionnel disponible pour ce service.',
                ),
              ),
            ...technicians.map(
              (t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: jefCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: jefPale,
                            child: Text(
                              jefText(t['prenom']).isNotEmpty
                                  ? jefText(t['prenom'])[0].toUpperCase()
                                  : 'J',
                              style: const TextStyle(
                                color: jefDark,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (jefText(t['prenom']) +
                                          ' ' +
                                          jefText(t['nom']))
                                      .trim(),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  jefMoney(t['tarifMin']) +
                                      ' – ' +
                                      jefMoney(t['tarifMax']),
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          jefPill('Disponible'),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: jefOrange,
                            size: 18,
                          ),
                          Text(
                            ' ' +
                                jefText(
                                  t['noteMoyenne'],
                                ).replaceAll('null', '–'),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 160,
                            child: ElevatedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => NewMissionPage(
                                    session: widget.session,
                                    service: widget.service,
                                    technician: t,
                                  ),
                                ),
                              ),
                              child: const Text('Demander'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class NewMissionPage extends StatefulWidget {
  const NewMissionPage({
    super.key,
    required this.session,
    required this.service,
    this.technician,
  });
  final JefSession session;
  final Map<String, dynamic> service;
  final Map<String, dynamic>? technician;
  @override
  State<NewMissionPage> createState() => _NewMissionPageState();
}

class _NewMissionPageState extends State<NewMissionPage> {
  final description = TextEditingController(), price = TextEditingController();
  bool sending = false;
  @override
  void dispose() {
    description.dispose();
    price.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    final clientId = widget.session.profileId;
    final serviceId = jefId(widget.service['id']);
    if (clientId == null) {
      jefError(context, const JefError('Profil client introuvable.'));
      return;
    }
    if (serviceId == null) {
      jefError(context, const JefError('Service introuvable.'));
      return;
    }
    if (description.text.trim().length < 10) {
      jefError(
        context,
        const JefError('Décrivez le besoin en au moins 10 caractères.'),
      );
      return;
    }
    final proposed = price.text.trim().isEmpty
        ? null
        : double.tryParse(price.text.replaceAll(',', '.'));
    if (price.text.trim().isNotEmpty &&
        (proposed == null || !proposed.isFinite || proposed <= 0)) {
      jefError(context, const JefError('Montant proposé incorrect.'));
      return;
    }
    setState(() => sending = true);
    try {
      final position = await jefPosition();
      await widget.session.api.createMission(
        clientId: clientId,
        serviceId: serviceId,
        technicianId: jefId(widget.technician?['id']),
        description: description.text.trim(),
        latitude: position.latitude,
        longitude: position.longitude,
        budget: proposed,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Demande créée avec succès')),
      );
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (mounted) jefError(context, e);
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nouvelle demande')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        jefTitle(
          jefText(widget.service['nom']),
          subtitle: 'Décrivez votre intervention.',
        ),
        const SizedBox(height: 20),
        if (widget.technician != null)
          jefCard(
            child: Row(
              children: [
                const Icon(Icons.person_pin_rounded, color: jefPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    jefText(widget.technician?['prenom']) +
                        ' ' +
                        jefText(widget.technician?['nom']),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: description,
          maxLines: 5,
          maxLength: 500,
          decoration: const InputDecoration(
            labelText: 'Description du besoin',
            hintText: 'Expliquez votre problème en détail...',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: price,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Prix proposé (facultatif)',
            suffixText: 'FCFA',
          ),
        ),
        const SizedBox(height: 14),
        jefCard(
          child: const Row(
            children: [
              Icon(Icons.location_on_outlined, color: jefPrimary),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Votre position sera utilisée au moment de créer la demande.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        ElevatedButton(
          onPressed: sending ? null : submit,
          child: sending
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Confirmer la demande'),
        ),
      ],
    ),
  );
}

class MissionsPage extends StatefulWidget {
  const MissionsPage({super.key, required this.session});
  final JefSession session;
  @override
  State<MissionsPage> createState() => _MissionsPageState();
}

class _MissionsPageState extends State<MissionsPage> {
  late Future<List<Map<String, dynamic>>> future;
  bool get professional => widget.session.role == JefRole.technician;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    final id = widget.session.profileId;
    future = id == null
        ? Future.value([])
        : widget.session.api.missions(id, professional: professional);
  }

  Future<void> change(Map<String, dynamic> m, String next) async {
    final id = jefId(m['id']), professionalId = widget.session.profileId;
    if (id == null || professionalId == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer cette action'),
        content: Text('Passer la mission à «' + jefStatus(next) + '» ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await widget.session.api.changeMissionStatus(
        id,
        jefText(m['statut']),
        next,
        professionalId,
      );
      if (mounted) setState(reload);
    } catch (e) {
      if (mounted) jefError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: () async {
      setState(reload);
      try {
        await future;
      } catch (_) {
        /* FutureBuilder affiche l'erreur. */
      }
    },
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        jefTitle(
          professional ? 'Mes interventions' : 'Mes demandes',
          subtitle: 'Consultez le suivi des missions Jef Service.',
        ),
        const SizedBox(height: 20),
        if (widget.session.profileId == null)
          jefCard(
            child: const Text(
              'Votre profil métier n’est pas disponible. Vérifiez votre compte et l’API.',
            ),
          ),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done)
              return const Padding(
                padding: EdgeInsets.all(36),
                child: Center(child: CircularProgressIndicator()),
              );
            if (snap.hasError)
              return jefCard(
                child: Column(
                  children: [
                    Text(snap.error.toString()),
                    TextButton(
                      onPressed: () => setState(reload),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              );
            final list = snap.data ?? [];
            if (list.isEmpty)
              return jefCard(
                child: const Text('Aucune mission pour le moment.'),
              );
            return Column(
              children: list.map((m) {
                final status = jefText(m['statut']);
                final next = professional
                    ? <String, String>{
                        'EN_ATTENTE': 'ACCEPTEE',
                        'ACCEPTEE': 'EN_COURS',
                        'EN_COURS': 'TERMINEE',
                      }[status]
                    : null;
                final service = jefMap(m['serviceJef']);
                final technician = jefMap(m['technicien']);
                final payment = jefMap(m['paiement']);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: jefCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                jefText(service['nom']).isEmpty
                                    ? 'Intervention'
                                    : jefText(service['nom']),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                            ),
                            jefPill(
                              jefStatus(status),
                              color: status == 'EN_ATTENTE'
                                  ? jefOrange
                                  : jefPrimary,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          jefText(m['description']),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Proposition : ' + jefMoney(m['prixPropose']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: jefDark,
                          ),
                        ),
                        if (!professional && technician.isNotEmpty)
                          Text(
                            'Intervenant : ' +
                                jefText(technician['prenom']) +
                                ' ' +
                                jefText(technician['nom']),
                          ),
                        if (payment.isNotEmpty)
                          Text(
                            'Paiement : ' +
                                jefText(payment['statut']) +
                                ' • ' +
                                jefMoney(payment['montantTotal']),
                          ),
                        if (next != null) ...[
                          const SizedBox(height: 14),
                          ElevatedButton(
                            onPressed: () => change(m, next),
                            child: Text(
                              next == 'ACCEPTEE'
                                  ? 'Accepter la mission'
                                  : next == 'EN_COURS'
                                  ? 'Démarrer l’intervention'
                                  : 'Terminer l’intervention',
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    ),
  );
}

class ProDashboard extends StatefulWidget {
  const ProDashboard({super.key, required this.session});
  final JefSession session;
  @override
  State<ProDashboard> createState() => _ProDashboardState();
}

class _ProDashboardState extends State<ProDashboard> {
  Map<String, dynamic>? tech;
  bool busy = false;
  bool loading = true;
  Object? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final id = widget.session.profileId;
    if (id == null) {
      if (mounted)
        setState(() {
          loading = false;
          tech = null;
          error = const JefError('Profil technicien introuvable.');
        });
      return;
    }
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      final result = await widget.session.api.technician(id);
      if (mounted)
        setState(() {
          tech = result;
          error = null;
        });
    } catch (e) {
      if (mounted)
        setState(() {
          tech = null;
          error = e;
        });
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> toggle(bool value) async {
    final id = widget.session.profileId;
    if (id == null || busy) return;
    setState(() => busy = true);
    try {
      await widget.session.api.availability(id, value);
      await load();
    } catch (e) {
      if (mounted) jefError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      jefTitle(
        'Espace professionnel',
        subtitle: 'Gérez votre activité et vos interventions.',
      ),
      const SizedBox(height: 24),
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [jefPrimary, jefDark]),
          borderRadius: BorderRadius.circular(25),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.business_center_outlined, size: 38, color: jefOrange),
            SizedBox(height: 13),
            Text(
              'Votre activité Jef Service',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 21,
              ),
            ),
            SizedBox(height: 6),
            Text(
              'Une expérience professionnelle simplifiée.',
              style: TextStyle(color: jefPale),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      if (loading)
        jefCard(
          child: const Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 14),
              Expanded(
                child: Text('Chargement de votre profil professionnel...'),
              ),
            ],
          ),
        ),
      if (!loading && error != null)
        jefCard(
          child: Text(
            error is JefError
                ? (error as JefError).message
                : 'Le profil est momentanément inaccessible.',
          ),
        ),
      if (!loading && tech == null && error == null)
        jefCard(child: const Text('Aucun profil professionnel disponible.')),
      if (tech != null)
        jefCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'État de votre compte',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              const SizedBox(height: 9),
              jefPill(
                jefText(tech!['statutValidation']),
                color: tech!['statutValidation'] == 'VALIDE'
                    ? jefPrimary
                    : jefOrange,
              ),
              const Divider(height: 27),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Disponible pour les missions'),
                subtitle: Text(
                  tech!['statutValidation'] == 'VALIDE'
                      ? 'Activez pour apparaître dans les recherches.'
                      : 'Validation administrateur nécessaire.',
                ),
                value: tech!['disponible'] == true,
                onChanged: busy || tech!['statutValidation'] != 'VALIDE'
                    ? null
                    : toggle,
              ),
              const SizedBox(height: 8),
              Text(
                'Tarifs : ' +
                    jefMoney(tech!['tarifMin']) +
                    ' – ' +
                    jefMoney(tech!['tarifMax']),
              ),
            ],
          ),
        ),
      const SizedBox(height: 20),
      ElevatedButton(
        onPressed: load,
        child: const Text('Actualiser mon profil'),
      ),
    ],
  );
}

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key, required this.session});
  final JefSession session;
  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  PlatformFile? cni, diploma;
  bool busy = false;
  late Future<List<Map<String, dynamic>>> future;
  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    final id = widget.session.profileId;
    future = id == null ? Future.value([]) : widget.session.api.documents(id);
  }

  Future<void> choose(bool identity) async {
    if (busy) return;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.size == 0 || file.size > 8 * 1024 * 1024 || file.path == null) {
        jefError(
          context,
          const JefError('Choisissez un fichier valide de 8 Mo maximum.'),
        );
        return;
      }
      setState(() {
        if (identity)
          cni = file;
        else
          diploma = file;
      });
    } catch (_) {
      if (mounted)
        jefError(
          context,
          const JefError(
            'Impossible de sélectionner ce fichier. Vérifiez les autorisations du téléphone.',
          ),
        );
    }
  }

  Future<void> send() async {
    final id = widget.session.profileId;
    if (id == null || cni?.path == null || diploma?.path == null) return;
    setState(() => busy = true);
    try {
      await widget.session.api.uploadDocuments(id, cni!.path!, diploma!.path!);
      if (!mounted) return;
      setState(() {
        cni = null;
        diploma = null;
        reload();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Documents envoyés. En attente de validation.'),
        ),
      );
    } catch (e) {
      if (mounted) jefError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      jefTitle(
        'Mes documents',
        subtitle: 'Identité et diplôme nécessaires pour validation.',
      ),
      const SizedBox(height: 20),
      jefCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.badge_outlined, color: jefPrimary),
              title: const Text('Pièce d’identité (CNI)'),
              subtitle: Text(cni?.name ?? 'PDF ou image, 8 Mo maximum'),
              trailing: IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () => choose(true),
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.school_outlined, color: jefPrimary),
              title: const Text('Diplôme'),
              subtitle: Text(diploma?.name ?? 'PDF ou image, 8 Mo maximum'),
              trailing: IconButton(
                icon: const Icon(Icons.attach_file),
                onPressed: () => choose(false),
              ),
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: busy || cni == null || diploma == null ? null : send,
              child: busy
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Envoyer mes documents'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      jefTitle('Documents transmis'),
      const SizedBox(height: 12),
      FutureBuilder<List<Map<String, dynamic>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done)
            return const Center(child: CircularProgressIndicator());
          if (snap.hasError) return Text(snap.error.toString());
          final data = snap.data ?? [];
          if (data.isEmpty)
            return jefCard(child: const Text('Aucun document enregistré.'));
          return Column(
            children: data
                .map(
                  (d) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: jefCard(
                      child: Row(
                        children: [
                          const Icon(
                            Icons.description_outlined,
                            color: jefPrimary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  jefText(d['type']),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  jefText(d['fileName']),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          jefPill(
                            d['valide'] == true
                                ? 'Validé'
                                : d['valide'] == false
                                ? 'Non validé'
                                : 'En attente',
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
    ],
  );
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, required this.session});
  final JefSession session;
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _AccountChanges {
  const _AccountChanges({
    required this.firstName,
    required this.lastName,
    required this.email,
  });
  final String firstName;
  final String lastName;
  final String? email;
}

class _EditAccountDialog extends StatefulWidget {
  const _EditAccountDialog({required this.account});
  final Map<String, dynamic> account;
  @override
  State<_EditAccountDialog> createState() => _EditAccountDialogState();
}

class _EditAccountDialogState extends State<_EditAccountDialog> {
  late final TextEditingController first;
  late final TextEditingController last;
  late final TextEditingController email;

  @override
  void initState() {
    super.initState();
    first = TextEditingController(text: jefText(widget.account['firstName']));
    last = TextEditingController(text: jefText(widget.account['lastName']));
    email = TextEditingController(text: jefText(widget.account['email']));
  }

  @override
  void dispose() {
    first.dispose();
    last.dispose();
    email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Modifier mon profil'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: first,
            decoration: const InputDecoration(labelText: 'Prénom'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: last,
            decoration: const InputDecoration(labelText: 'Nom'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-mail'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Annuler'),
      ),
      FilledButton(
        onPressed: () {
          final cleanedEmail = email.text.trim();
          if (cleanedEmail.isNotEmpty &&
              !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(cleanedEmail)) {
            jefError(
              context,
              const JefError('Veuillez saisir une adresse e-mail valide.'),
            );
            return;
          }
          Navigator.pop(
            context,
            _AccountChanges(
              firstName: first.text.trim(),
              lastName: last.text.trim(),
              email: cleanedEmail.isEmpty ? null : cleanedEmail,
            ),
          );
        },
        child: const Text('Enregistrer'),
      ),
    ],
  );
}

class _ProfilePageState extends State<ProfilePage> {
  bool saving = false;
  Future<void> edit() async {
    final data = widget.session.accountData;
    final result = await showDialog<_AccountChanges>(
      context: context,
      builder: (_) => _EditAccountDialog(account: data),
    );
    if (!mounted || result == null) return;
    setState(() => saving = true);
    try {
      await widget.session.api.updateAccount({
        'login': data['login'],
        'firstName': result.firstName,
        'lastName': result.lastName,
        'email': result.email,
        'langKey': jefText(data['langKey']).isEmpty ? 'fr' : data['langKey'],
        'imageUrl': data['imageUrl'],
      });
      await widget.session.refresh();
    } catch (e) {
      if (mounted) jefError(context, e);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.session.accountData;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        jefTitle('Mon compte', subtitle: 'Vos informations et paramètres.'),
        const SizedBox(height: 22),
        jefCard(
          child: Column(
            children: [
              const CircleAvatar(
                radius: 34,
                backgroundColor: jefPale,
                child: Icon(Icons.person_rounded, size: 39, color: jefDark),
              ),
              const SizedBox(height: 15),
              Text(
                (jefText(account['firstName']) +
                            ' ' +
                            jefText(account['lastName']))
                        .trim()
                        .isEmpty
                    ? jefText(account['login'])
                    : (jefText(account['firstName']) +
                              ' ' +
                              jefText(account['lastName']))
                          .trim(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 7),
              jefPill(
                widget.session.role == JefRole.client
                    ? 'Client'
                    : 'Professionnel',
              ),
              const SizedBox(height: 12),
              Text(jefText(account['login'])),
              if (jefText(account['email']).isNotEmpty)
                Text(jefText(account['email'])),
            ],
          ),
        ),
        const SizedBox(height: 18),
        jefCard(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(
                  Icons.manage_accounts_outlined,
                  color: jefPrimary,
                ),
                title: const Text('Modifier mes informations'),
                trailing: saving
                    ? const CircularProgressIndicator()
                    : const Icon(Icons.chevron_right),
                onTap: saving ? null : edit,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.refresh_outlined, color: jefPrimary),
                title: const Text('Actualiser le compte'),
                onTap: () async {
                  try {
                    await widget.session.refresh();
                  } catch (e) {
                    if (context.mounted) jefError(context, e);
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout_rounded, color: jefOrange),
                title: const Text('Se déconnecter'),
                onTap: () async {
                  await widget.session.logout();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
