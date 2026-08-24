import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DatabaseHelper.instance.database;
  runApp(MiApp());
}

// --- BASE DE DATOS LOCAL SQLITE ---
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('Base_De_Datos_App_Ventas.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clientes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        telefono TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE productos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nombre TEXT NOT NULL,
        precio REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE pedidos (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cliente TEXT NOT NULL,
        telefono TEXT NOT NULL,
        total REAL NOT NULL,
        detalle TEXT NOT NULL,
        fecha TEXT NOT NULL
      )
    ''');

    // Datos por defecto
    await db.insert('clientes', {'nombre': 'Juan Pérez', 'telefono': '50432152136'});
    await db.insert('productos', {'nombre': 'Café Molido 500g', 'precio': 100.0});
    await db.insert('productos', {'nombre': 'Filtros de Papel', 'precio': 50.0});
  }
}

// --- MODELOS ---
class Cliente {
  final int? id;
  final String nombre;
  final String telefono;
  Cliente({this.id, required this.nombre, required this.telefono});

  Map<String, dynamic> toMap() => {'id': id, 'nombre': nombre, 'telefono': telefono};
  factory Cliente.fromMap(Map<String, dynamic> map) => Cliente(
    id: map['id'],
    nombre: map['nombre'],
    telefono: map['telefono'],
  );
}

class Producto {
  final int? id;
  final String nombre;
  final double precio;
  Producto({this.id, required this.nombre, required this.precio});

  Map<String, dynamic> toMap() => {'id': id, 'nombre': nombre, 'precio': precio};
  factory Producto.fromMap(Map<String, dynamic> map) => Producto(
    id: map['id'],
    nombre: map['nombre'],
    precio: map['precio'],
  );
}

class Pedido {
  final int? id;
  final String cliente;
  final String telefono;
  final double total;
  final String detalle;
  final String fecha;

  Pedido({this.id, required this.cliente, required this.telefono, required this.total, required this.detalle, required this.fecha});

  Map<String, dynamic> toMap() => {
    'id': id,
    'cliente': cliente,
    'telefono': telefono,
    'total': total,
    'detalle': detalle,
    'fecha': fecha,
  };

  factory Pedido.fromMap(Map<String, dynamic> map) => Pedido(
    id: map['id'],
    cliente: map['cliente'],
    telefono: map['telefono'],
    total: map['total'],
    detalle: map['detalle'],
    fecha: map['fecha'],
  );
}

// --- APLICACIÓN PRINCIPAL ---
class MiApp extends StatelessWidget {
  MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: PantallaPrincipal(),
    );
  }
}

class PantallaPrincipal extends StatefulWidget {
  PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Sistema de Pedidos'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Nuevo Pedido'),
              Tab(text: 'Historial'),
              Tab(text: 'Clientes'),
              Tab(text: 'Productos'),
              Tab(text: 'Resumen'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            VistaNuevoPedido(),
            VistaHistorial(),
            VistaGestionClientes(),
            VistaGestionProductos(),
            VistaResumenes(),
          ],
        ),
      ),
    );
  }
}

// --- VISTA 1 & 2: NUEVO PEDIDO Y SELECCIÓN DE PRODUCTOS ---
class VistaNuevoPedido extends StatefulWidget {
  VistaNuevoPedido({super.key});

  @override
  State<VistaNuevoPedido> createState() => _VistaNuevoPedidoState();
}

class _VistaNuevoPedidoState extends State<VistaNuevoPedido> {
  Cliente? clienteSeleccionado;
  Map<Producto, int> carrito = {};

  double get totalPedido => carrito.entries.fold(0, (sum, entry) => sum + (entry.key.precio * entry.value));

  void _abrirBuscadorCliente() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> res = await db.query('clientes');
    List<Cliente> clientes = res.map((c) => Cliente.fromMap(c)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        String filtro = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtrados = clientes.where((c) => c.nombre.toLowerCase().contains(filtro.toLowerCase())).toList();
            return Container(
              padding: EdgeInsets.all(16),
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(labelText: 'Buscar Cliente', prefixIcon: Icon(Icons.search)),
                    onChanged: (val) => setModalState(() => filtro = val),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtrados.length,
                      itemBuilder: (ctx, i) => ListTile(
                        title: Text(filtrados[i].nombre),
                        subtitle: Text(filtrados[i].telefono),
                        onTap: () {
                          setState(() => clienteSeleccionado = filtrados[i]);
                          Navigator.pop(ctx);
                        },
                      ),
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _abrirCatalogoProductos() async {
    final db = await DatabaseHelper.instance.database;
    final List<Map<String, dynamic>> res = await db.query('productos');
    List<Producto> productos = res.map((p) => Producto.fromMap(p)).toList();

    showDialog(
      context: context,
      builder: (ctx) {
        String filtro = '';
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filtrados = productos.where((p) => p.nombre.toLowerCase().contains(filtro.toLowerCase())).toList();
            return AlertDialog(
              title: Text('Catálogo de Productos'),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(labelText: 'Buscar Producto', prefixIcon: Icon(Icons.search)),
                      onChanged: (val) => setDialogState(() => filtro = val),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: filtrados.length,
                        itemBuilder: (ctx, i) {
                          final prod = filtrados[i];
                          final cant = carrito[prod] ?? 0;
                          return ListTile(
                            title: Text(prod.nombre),
                            subtitle: Text('L ${prod.precio.toStringAsFixed(2)} c/u'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.remove_circle_outline),
                                  onPressed: cant > 0
                                      ? () {
                                          setDialogState(() {
                                            setState(() {
                                              if (cant == 1) {
                                                carrito.remove(prod);
                                              } else {
                                                carrito[prod] = cant - 1;
                                              }
                                            });
                                          });
                                        }
                                      : null,
                                ),
                                Text('$cant', style: TextStyle(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: Icon(Icons.add_circle_outline),
                                  onPressed: () {
                                    setDialogState(() {
                                      setState(() {
                                        carrito[prod] = cant + 1;
                                      });
                                    });
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                ElevatedButton(onPressed: () => Navigator.pop(ctx), child: Text('Listo')),
              ],
            );
          },
        );
      },
    );
  }

  void _enviarWhatsApp() async {
    if (clienteSeleccionado == null || carrito.isEmpty) return;

    String detalleText = '';
    carrito.forEach((prod, cant) {
      detalleText += '• ${cant}x ${prod.nombre} (L ${(prod.precio * cant).toStringAsFixed(2)})\n';
    });

    final db = await DatabaseHelper.instance.database;
    final nuevoPedido = Pedido(
      cliente: clienteSeleccionado!.nombre,
      telefono: clienteSeleccionado!.telefono,
      total: totalPedido,
      detalle: detalleText,
      fecha: DateTime.now().toString().substring(0, 10),
    );

    await db.insert('pedidos', nuevoPedido.toMap());

    String mensaje = '¡Hola ${clienteSeleccionado!.nombre}!\n\nDetalle de tu pedido:\n$detalleText\nTotal: L ${totalPedido.toStringAsFixed(2)}';
    final url = Uri.parse('https://wa.me/${clienteSeleccionado!.telefono}?text=${Uri.encodeComponent(mensaje)}');
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }

    setState(() {
      carrito.clear();
      clienteSeleccionado = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          OutlinedButton.icon(
            icon: Icon(Icons.person_search),
            label: Text(clienteSeleccionado == null ? 'Seleccionar Cliente' : 'Cliente: ${clienteSeleccionado!.nombre}'),
            onPressed: _abrirBuscadorCliente,
          ),
          SizedBox(height: 10),
          ElevatedButton.icon(
            icon: Icon(Icons.add),
            label: Text('+ Agregar Productos al Pedido'),
            onPressed: _abrirCatalogoProductos,
          ),
          Divider(),
          Expanded(
            child: carrito.isEmpty
                ? Center(child: Text('Ningún producto agregado aún.'))
                : ListView(
                    children: carrito.entries.map((entry) {
                      return Card(
                        child: ListTile(
                          title: Text(entry.key.nombre),
                          subtitle: Text('L ${entry.key.precio.toStringAsFixed(2)} c/u | Subtotal: L ${(entry.key.precio * entry.value).toStringAsFixed(2)}'),
                          trailing: Text('Cant: ${entry.value}', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            color: Colors.green.shade50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text('L ${totalPedido.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green.shade900)),
              ],
            ),
          ),
          SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              onPressed: (clienteSeleccionado != null && carrito.isNotEmpty) ? _enviarWhatsApp : null,
              child: Text('Enviar Pedido por WhatsApp', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }
}

// --- VISTA 3 Y 7: HISTORIAL DE PEDIDOS Y REENVÍO ---
class VistaHistorial extends StatefulWidget {
  VistaHistorial({super.key});

  @override
  State<VistaHistorial> createState() => _VistaHistorialState();
}

class _VistaHistorialState extends State<VistaHistorial> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.database.then((db) => db.query('pedidos', orderBy: 'id DESC')),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final pedidos = snapshot.data!.map((p) => Pedido.fromMap(p)).toList();

        if (pedidos.isEmpty) return Center(child: Text('No hay pedidos registrados.'));

        return ListView.builder(
          itemCount: pedidos.length,
          itemBuilder: (ctx, i) {
            final ped = pedidos[i];
            return Card(
              margin: EdgeInsets.all(8),
              child: ExpansionTile(
                title: Text('Pedido #${ped.id} - ${ped.cliente}'),
                subtitle: Text('Total: L ${ped.total.toStringAsFixed(2)} | Fecha: ${ped.fecha}'),
                children: [
                  Padding(
                    padding: EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Teléfono: ${ped.telefono}'),
                        Text('Detalle:\n${ped.detalle}'),
                        OutlinedButton.icon(
                          icon: Icon(Icons.send),
                          label: Text('Reenviar por WhatsApp'),
                          onPressed: () async {
                            String mensaje = '¡Hola ${ped.cliente}!\n\nRecordatorio de tu pedido:\n${ped.detalle}\nTotal: L ${ped.total.toStringAsFixed(2)}';
                            final url = Uri.parse('https://wa.me/${ped.telefono}?text=${Uri.encodeComponent(mensaje)}');
                            if (await canLaunchUrl(url)) await launchUrl(url);
                          },
                        )
                      ],
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// --- VISTA 5: GESTIÓN DE CLIENTES ---
class VistaGestionClientes extends StatefulWidget {
  VistaGestionClientes({super.key});

  @override
  State<VistaGestionClientes> createState() => _VistaGestionClientesState();
}

class _VistaGestionClientesState extends State<VistaGestionClientes> {
  final _nombreCtrl = TextEditingController();
  final _telCtrl = TextEditingController();

  void _agregarCliente() async {
    if (_nombreCtrl.text.isEmpty || _telCtrl.text.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    await db.insert('clientes', {'nombre': _nombreCtrl.text, 'telefono': _telCtrl.text});
    _nombreCtrl.clear();
    _telCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _nombreCtrl, decoration: InputDecoration(labelText: 'Nombre'))),
              SizedBox(width: 8),
              Expanded(child: TextField(controller: _telCtrl, decoration: InputDecoration(labelText: 'Teléfono'))),
              IconButton(icon: Icon(Icons.add_circle, color: Colors.green), onPressed: _agregarCliente)
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.database.then((db) => db.query('clientes')),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              final clientes = snapshot.data!.map((c) => Cliente.fromMap(c)).toList();
              return ListView.builder(
                itemCount: clientes.length,
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(clientes[i].nombre),
                  subtitle: Text(clientes[i].telefono),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final db = await DatabaseHelper.instance.database;
                      await db.delete('clientes', where: 'id = ?', whereArgs: [clientes[i].id]);
                      setState(() {});
                    },
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}

// --- VISTA 6: GESTIÓN DE PRODUCTOS ---
class VistaGestionProductos extends StatefulWidget {
  VistaGestionProductos({super.key});

  @override
  State<VistaGestionProductos> createState() => _VistaGestionProductosState();
}

class _VistaGestionProductosState extends State<VistaGestionProductos> {
  final _nombreCtrl = TextEditingController();
  final _precioCtrl = TextEditingController();

  void _agregarProducto() async {
    if (_nombreCtrl.text.isEmpty || _precioCtrl.text.isEmpty) return;
    final db = await DatabaseHelper.instance.database;
    await db.insert('productos', {
      'nombre': _nombreCtrl.text,
      'precio': double.tryParse(_precioCtrl.text) ?? 0.0,
    });
    _nombreCtrl.clear();
    _precioCtrl.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(child: TextField(controller: _nombreCtrl, decoration: InputDecoration(labelText: 'Producto'))),
              SizedBox(width: 8),
              Expanded(child: TextField(controller: _precioCtrl, decoration: InputDecoration(labelText: 'Precio (L)'), keyboardType: TextInputType.number)),
              IconButton(icon: Icon(Icons.add_circle, color: Colors.green), onPressed: _agregarProducto)
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.database.then((db) => db.query('productos')),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
              final productos = snapshot.data!.map((p) => Producto.fromMap(p)).toList();
              return ListView.builder(
                itemCount: productos.length,
                itemBuilder: (ctx, i) => ListTile(
                  title: Text(productos[i].nombre),
                  subtitle: Text('Precio: L ${productos[i].precio.toStringAsFixed(2)}'),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      final db = await DatabaseHelper.instance.database;
                      await db.delete('productos', where: 'id = ?', whereArgs: [productos[i].id]);
                      setState(() {});
                    },
                  ),
                ),
              );
            },
          ),
        )
      ],
    );
  }
}

// --- VISTA ADICIONAL: RESUMEN Y REPORTES DE VENTAS ---
class VistaResumenes extends StatelessWidget {
  VistaResumenes({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.database.then((db) => db.query('pedidos')),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return Center(child: CircularProgressIndicator());
        final pedidos = snapshot.data!.map((p) => Pedido.fromMap(p)).toList();

        double totalVentas = pedidos.fold(0, (sum, p) => sum + p.total);
        Map<String, double> ventasPorCliente = {};

        for (var p in pedidos) {
          ventasPorCliente[p.cliente] = (ventasPorCliente[p.cliente] ?? 0) + p.total;
        }

        return Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                color: Colors.green.shade100,
                child: ListTile(
                  title: Text('Ventas Totales Registradas', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('L ${totalVentas.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                ),
              ),
              SizedBox(height: 15),
              Text('Resumen de Ventas por Cliente:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Divider(),
              Expanded(
                child: ListView(
                  children: ventasPorCliente.entries.map((e) {
                    return ListTile(
                      leading: Icon(Icons.person),
                      title: Text(e.key),
                      trailing: Text('L ${e.value.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold)),
                    );
                  }).toList(),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}
