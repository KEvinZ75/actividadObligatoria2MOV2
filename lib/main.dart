import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' show join;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:url_launcher/url_launcher.dart';

const claveAutenticado = 'autenticado';

Uri telUri(String telefono) =>
    Uri(scheme: 'tel', path: telefono.replaceAll(RegExp(r'[^\d+]'), ''));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ContactosProvider()..cargar(),
      child: MiAgendaApp(autenticado: prefs.getBool(claveAutenticado) ?? false),
    ),
  );
}

class MiAgendaApp extends StatelessWidget {
  final bool autenticado;

  const MiAgendaApp({super.key, required this.autenticado});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Agenda',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: autenticado ? const ContactosScreen() : const LoginScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/contactos': (_) => const ContactosScreen(),
        '/agregar': (ctx) => AgregarContactoScreen(
              contacto: ModalRoute.of(ctx)!.settings.arguments as Contacto?,
            ),
      },
    );
  }
}


class Contacto {
  final int? id;
  final String nombre;
  final String apellido;
  final String telefono;
  final String email;
  final String domicilio;
  final DateTime? fechaNacimiento;
  final String genero;

  Contacto({
    this.id,
    required this.nombre,
    required this.apellido,
    required this.telefono,
    required this.email,
    required this.domicilio,
    required this.fechaNacimiento,
    required this.genero,
  });

  String get nombreCompleto => '$nombre $apellido';

  factory Contacto.fromMap(Map<String, Object?> m) => Contacto(
        id: m['id'] as int,
        nombre: m['nombre'] as String,
        apellido: m['apellido'] as String,
        telefono: m['telefono'] as String,
        email: m['email'] as String,
        domicilio: m['domicilio'] as String,
        fechaNacimiento: DateTime.tryParse(m['fecha_nacimiento'] as String? ?? ''),
        genero: m['genero'] as String,
      );

  Map<String, Object?> toMap() => {
        'nombre': nombre,
        'apellido': apellido,
        'telefono': telefono,
        'email': email,
        'domicilio': domicilio,
        'fecha_nacimiento': fechaNacimiento?.toIso8601String(),
        'genero': genero,
      };
}

class ContactosProvider extends ChangeNotifier {
  List<Contacto> _contactos = [];

  List<Contacto> get contactos => List.unmodifiable(_contactos);

  Future<Database> _abrir() async => openDatabase(
        join(await getDatabasesPath(), 'agenda.db'),
        version: 1,
        onCreate: (db, _) => db.execute('''
          CREATE TABLE contactos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            nombre TEXT NOT NULL,
            apellido TEXT NOT NULL,
            telefono TEXT NOT NULL,
            email TEXT NOT NULL,
            domicilio TEXT NOT NULL,
            fecha_nacimiento TEXT,
            genero TEXT NOT NULL
          )
        '''),
      );

  Future<void> cargar() async {
    final db = await _abrir();
    final filas = await db.query('contactos',
        orderBy: 'nombre COLLATE NOCASE, apellido COLLATE NOCASE');
    _contactos = filas.map(Contacto.fromMap).toList();
    notifyListeners();
  }

  Future<void> agregar(Contacto c) async {
    final db = await _abrir();
    await db.insert('contactos', c.toMap());
    await cargar();
  }

  Future<void> actualizar(Contacto c) async {
    final db = await _abrir();
    await db.update('contactos', c.toMap(), where: 'id = ?', whereArgs: [c.id]);
    await cargar();
  }

  Future<void> eliminar(int id) async {
    final db = await _abrir();
    await db.delete('contactos', where: 'id = ?', whereArgs: [id]);
    await cargar();
  }

  List<Contacto> filtrar(String texto) {
    final q = texto.trim().toLowerCase();
    if (q.isEmpty) return contactos;
    return _contactos
        .where((c) =>
            c.nombreCompleto.toLowerCase().contains(q) ||
            c.telefono.contains(q))
        .toList();
  }
}


class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usuarioCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  static const _usuarioValido = 'admin@agenda.com';
  static const _passValida = '1234';

  Future<void> _iniciarSesion() async {
    if (!_formKey.currentState!.validate()) return;
    if (_usuarioCtrl.text.trim() == _usuarioValido &&
        _passCtrl.text == _passValida) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(claveAutenticado, true);
      if (mounted) Navigator.pushReplacementNamed(context, '/contactos');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Usuario o contraseña incorrectos')),
      );
    }
  }

  @override
  void dispose() {
    _usuarioCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.account_circle, size: 96, color: Colors.blue),
                  const SizedBox(height: 8),
                  const Text('Mi Agenda',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, color: Colors.blue)),
                  const SizedBox(height: 32),
                  const Text('Usuario'),
                  TextFormField(
                    controller: _usuarioCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        hintText: 'Ingrese email', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Ingrese el usuario' : null,
                  ),
                  const SizedBox(height: 16),
                  const Text('Contraseña'),
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(
                        hintText: 'Ingrese password', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Ingrese la contraseña' : null,
                  ),
                  const SizedBox(height: 32),
                  FilledButton(
                    onPressed: _iniciarSesion,
                    child: const Text('Iniciar sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class ContactosScreen extends StatefulWidget {
  const ContactosScreen({super.key});

  @override
  State<ContactosScreen> createState() => _ContactosScreenState();
}

class _ContactosScreenState extends State<ContactosScreen> {
  bool _buscando = false;
  final _busquedaCtrl = TextEditingController();

  void _cerrarBusqueda() {
    setState(() {
      _buscando = false;
      _busquedaCtrl.clear();
    });
  }

  Future<void> _cerrarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(claveAutenticado, false);
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _llamar(String telefono) async {
    bool abierto;
    try {
      abierto = await launchUrl(telUri(telefono));
    } on PlatformException {
      abierto = false;
    }
    if (!abierto && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir la app de teléfono')),
      );
    }
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactos = context.watch<ContactosProvider>().filtrar(_busquedaCtrl.text);

    return Scaffold(
      appBar: AppBar(
        leading: _buscando
            ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: _cerrarBusqueda)
            : null,
        title: _buscando
            ? TextField(
                controller: _busquedaCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Buscar...', border: InputBorder.none),
                onChanged: (_) => setState(() {}),
              )
            : const Text('Contactos'),
        actions: [
          if (_buscando)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(_busquedaCtrl.clear),
            )
          else
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => _buscando = true),
            ),
          PopupMenuButton<String>(
            onSelected: (_) => _cerrarSesion(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'salir', child: Text('Cerrar sesión')),
            ],
          ),
        ],
      ),
      body: contactos.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(_buscando ? 'Sin resultados' : 'Aún no tienes contactos',
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: contactos.length,
              itemBuilder: (_, i) {
                final c = contactos[i];
                return ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.grey,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(c.nombreCompleto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(c.telefono),
                  trailing: IconButton(
                    icon: const Icon(Icons.phone, color: Colors.green),
                    tooltip: 'Llamar',
                    onPressed: () => _llamar(c.telefono),
                  ),
                  onTap: () => Navigator.pushNamed(context, '/agregar', arguments: c),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/agregar'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AgregarContactoScreen extends StatefulWidget {
  final Contacto? contacto;

  const AgregarContactoScreen({super.key, this.contacto});

  @override
  State<AgregarContactoScreen> createState() => _AgregarContactoScreenState();
}

class _AgregarContactoScreenState extends State<AgregarContactoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nombreCtrl = TextEditingController(text: widget.contacto?.nombre);
  late final _apellidoCtrl = TextEditingController(text: widget.contacto?.apellido);
  late final _telefonoCtrl = TextEditingController(text: widget.contacto?.telefono ?? '+54 ');
  late final _emailCtrl = TextEditingController(text: widget.contacto?.email);
  late final _domicilioCtrl = TextEditingController(text: widget.contacto?.domicilio);
  late DateTime? _fechaNacimiento = widget.contacto?.fechaNacimiento;
  late String _genero = widget.contacto?.genero ?? 'Femenino';

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento ?? DateTime(2000),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (fecha != null) setState(() => _fechaNacimiento = fecha);
  }

  Future<void> _ejecutar(Future<void> Function() operacion) async {
    try {
      await operacion();
      if (mounted) Navigator.pop(context);
    } on DatabaseException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo completar la operación')),
        );
      }
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final agenda = context.read<ContactosProvider>();
    final contacto = Contacto(
      id: widget.contacto?.id,
      nombre: _nombreCtrl.text.trim(),
      apellido: _apellidoCtrl.text.trim(),
      telefono: _telefonoCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      domicilio: _domicilioCtrl.text.trim(),
      fechaNacimiento: _fechaNacimiento,
      genero: _genero,
    );
    await _ejecutar(() =>
        contacto.id == null ? agenda.agregar(contacto) : agenda.actualizar(contacto));
  }

  Future<void> _eliminar() async {
    final agenda = context.read<ContactosProvider>();
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar contacto'),
        content: Text('¿Eliminar a ${widget.contacto!.nombreCompleto}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmado == true) await _ejecutar(() => agenda.eliminar(widget.contacto!.id!));
  }

  @override
  void dispose() {
    for (final c in [_nombreCtrl, _apellidoCtrl, _telefonoCtrl, _emailCtrl, _domicilioCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _campo(String label, TextEditingController ctrl, String hint,
      {TextInputType? tipo, String? Function(String?)? validator}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label),
          TextFormField(
            controller: ctrl,
            keyboardType: tipo,
            decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
            validator: validator,
          ),
        ],
      ),
    );
  }

  String? _requerido(String? v) => (v == null || v.trim().isEmpty) ? 'Campo obligatorio' : null;

  @override
  Widget build(BuildContext context) {
    final fechaTexto = _fechaNacimiento == null
        ? 'Seleccionar fecha'
        : '${_fechaNacimiento!.day}/${_fechaNacimiento!.month}/${_fechaNacimiento!.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.contacto == null ? 'Agregar' : 'Editar'),
        actions: [
          if (widget.contacto != null)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Eliminar',
              onPressed: _eliminar,
            ),
          IconButton(icon: const Icon(Icons.check), tooltip: 'Guardar', onPressed: _guardar),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _campo('Nombre', _nombreCtrl, 'Ingrese nombre', validator: _requerido),
            _campo('Apellido', _apellidoCtrl, 'Ingrese apellido', validator: _requerido),
            _campo('Número de teléfono', _telefonoCtrl, '+54 __ ___ __ __',
                tipo: TextInputType.phone, validator: _requerido),
            _campo('Correo electrónico', _emailCtrl, 'Ingrese email',
                tipo: TextInputType.emailAddress,
                validator: (v) => (v != null && v.isNotEmpty && !v.contains('@'))
                    ? 'Email inválido'
                    : null),
            _campo('Domicilio', _domicilioCtrl, 'Ingrese domicilio'),
            const Text('Fecha de nacimiento'),
            OutlinedButton.icon(
              onPressed: _elegirFecha,
              icon: const Icon(Icons.calendar_today),
              label: Text(fechaTexto),
            ),
            const SizedBox(height: 16),
            const Text('Género'),
            for (final g in ['Femenino', 'Masculino'])
              RadioListTile<String>(
                title: Text(g),
                value: g,
                groupValue: _genero,
                onChanged: (v) => setState(() => _genero = v!),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
          ],
        ),
      ),
    );
  }
}
