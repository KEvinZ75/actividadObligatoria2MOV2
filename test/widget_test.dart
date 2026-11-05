import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mi_agenda/main.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget app({required bool autenticado}) => ChangeNotifierProvider(
      create: (_) => ContactosProvider(),
      child: MiAgendaApp(autenticado: autenticado),
    );

void main() {
  test('Contacto se conserva al pasar por una fila de la base', () {
    for (final fecha in [DateTime(2000, 1, 2), null]) {
      final fila = Contacto(
        nombre: 'Ana',
        apellido: 'Perez',
        telefono: '+54 11 1234',
        email: 'a@b.com',
        domicilio: 'Calle 1',
        fechaNacimiento: fecha,
        genero: 'Femenino',
      ).toMap();
      final c = Contacto.fromMap({'id': 7, ...fila});

      expect(c.id, 7);
      expect(c.nombreCompleto, 'Ana Perez');
      expect(c.fechaNacimiento, fecha);
    }
  });

  test('telUri deja solo el + y los dígitos del teléfono', () {
    expect(telUri('+54 11 1234-5678').toString(), 'tel:+541112345678');
    expect(telUri('(011) 4444 5555').toString(), 'tel:01144445555');
  });

  group('Sesión', () {
    testWidgets('sin sesión pide credenciales y el login la registra', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app(autenticado: false));
      expect(find.text('Iniciar sesión'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), 'admin@agenda.com');
      await tester.enterText(find.byType(TextFormField).at(1), '1234');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Contactos'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(claveAutenticado), true);
    });

    testWidgets('credenciales incorrectas no registran la sesión', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(app(autenticado: false));

      await tester.enterText(find.byType(TextFormField).at(0), 'admin@agenda.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'mal');
      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Usuario o contraseña incorrectos'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(claveAutenticado), isNull);
    });

    testWidgets('con sesión entra directo y cerrar sesión la invalida', (tester) async {
      SharedPreferences.setMockInitialValues({claveAutenticado: true});
      await tester.pumpWidget(app(autenticado: true));
      expect(find.text('Contactos'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cerrar sesión'));
      await tester.pumpAndSettle();

      expect(find.text('Iniciar sesión'), findsOneWidget);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(claveAutenticado), false);
    });
  });
}
