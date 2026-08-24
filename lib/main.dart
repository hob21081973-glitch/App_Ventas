import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const MiApp());

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      home: const PantallaPrincipal(),
    );
  }
}

// --- MODELOS DE DATOS ---
class Cliente {
  String id;
  String nombre;
  String telefono;

  Cliente({required this.id, required this.nombre, required this.telefono});
}

class Producto {
  String id;
  String nombre;
  double precio;

  Producto({required this.id, required this.nombre, required this.precio});
}

class ItemPedido {
  Producto producto;
  int cantidad;

  ItemPedido({required this.producto, required this.cantidad});

  double get subtotal => producto.precio * cantidad;
}

class Pedido {
  String numero;
  Cliente cliente;
  List<ItemPedido> items;
  DateTime fecha;

  Pedido({
    required this.numero,
    required this.cliente,
    required this.items,
    required this.fecha,
  });

  double get total => items.fold(0.0, (sum, item) => sum + item.subtotal);
}

// --- ALMACENAMIENTO GLOBAL ---
class DataStore {
  static List<Cliente> clientes = [
    Cliente(id: 'c1', nombre: "Juan Pérez", telefono: "50432152136"),
  ];

  static List<Producto> productos = [
    Producto(id: 'p1', nombre: "Café Molido 500g", precio: 100.0),
    Producto(id: 'p2', nombre: "Filtros de Papel", precio: 50.0),
  ];

  static List<Pedido> historialPedidos = [];
  static int numeroPedido = 1;
}

// --- PANTALLA PRINCIPAL ---
class PantallaPrincipal extends StatefulWidget {
  const PantallaPrincipal({super.key});

  @override
  State<PantallaPrincipal> createState() => _PantallaPrincipalState();
}

class _PantallaPrincipalState extends State<PantallaPrincipal> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sistema de Pedidos'),
          backgroundColor: Colors.green[700],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: [
              Tab(icon: Icon(Icons.add_shopping_cart), text: "Nuevo Pedido"),
              Tab(icon: Icon(Icons.receipt_long), text: "Historial"),
              Tab(icon: Icon(Icons.people), text: "Clientes"),
              Tab(icon: Icon(Icons.inventory_2), text: "Productos"),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            PantallaNuevoPedido(),
            PantallaHistorialPedidos(),
            PantallaClientes(),
            PantallaProductos(),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// PESTAÑA 1: NUEVO PEDIDO
// ==========================================
class PantallaNuevoPedido extends StatefulWidget {
  const PantallaNuevoPedido({super.key});

  @override
  State<PantallaNuevoPedido> createState() => _PantallaNuevoPedidoState();
}

class _PantallaNuevoPedidoState extends State<PantallaNuevoPedido> {
  Cliente? clienteSeleccionado;
  Map<String, int> cantidades = {};

  @override
  void initState() {
    super.initState();
    if (DataStore.clientes.isNotEmpty) {
      clienteSeleccionado = DataStore.clientes.first;
    }
  }

  double get totalActual {
    double total = 0.0;
    for (var prod in DataStore.productos) {
      int cant = cantidades[prod.id] ?? 0;
      total += (cant * prod.precio);
    }
    return total;
  }

  void _abrirCatalogoProductos() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text("Catálogo de Productos"),
              content: SizedBox(
                width: double.maxFinite,
                child: DataStore.productos.isEmpty
                    ? const Text("No hay productos cargados.")
                    : ListView.builder(
                        shrinkWrap: true,
                        itemCount: DataStore.productos.length,
                        itemBuilder: (context, i) {
                          final prod = DataStore.productos[i];
                          int cant = cantidades[prod.id] ?? 0;

                          return ListTile(
                            title: Text(prod.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text("\$${prod.precio.toStringAsFixed(2)} c/u"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () {
                                    if (cant > 0) {
                                      setModalState(() => cantidades[prod.id] = cant - 1);
                                      setState(() {});
                                    }
                                  },
                                ),
                                Text("$cant", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: () {
                                    setModalState(() => cantidades[prod.id] = cant + 1);
                                    setState(() {});
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Listo", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _enviarWhatsApp() async {
    if (clienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un cliente')),
      );
      return;
    }

    List<ItemPedido> itemsPedido = [];
    String detalleMsg = "";

    for (var prod in DataStore.productos) {
      int cant = cantidades[prod.id] ?? 0;
      if (cant > 0) {
        itemsPedido.add(ItemPedido(producto: prod, cantidad: cant));
        double subtotal = prod.precio * cant;
        detalleMsg += "• ${cant}x ${prod.nombre}: \$${subtotal.toStringAsFixed(2)}\n";
      }
    }

    if (itemsPedido.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto al pedido')),
      );
      return;
    }

    String numFormateado = DataStore.numeroPedido.toString().padLeft(2, '0');

    Pedido nuevoPedido = Pedido(
      numero: numFormateado,
      cliente: clienteSeleccionado!,
      items: itemsPedido,
      fecha: DateTime.now(),
    );

    DataStore.historialPedidos.insert(0, nuevoPedido);

    final String mensaje = "Estimado/a ${clienteSeleccionado!.nombre},\n\n"
        "📦 *Pedido #$numFormateado*\n"
        "$detalleMsg\n"
        "💰 *Total:* \$${nuevoPedido.total.toStringAsFixed(2)}";

    final Uri url = Uri.parse("https://wa.me/${clienteSeleccionado!.telefono}?text=${Uri.encodeComponent(mensaje)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      setState(() {
        DataStore.numeroPedido = DataStore.numeroPedido < 99 ? DataStore.numeroPedido + 1 : 1;
        cantidades.clear();
      });
    } else {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (DataStore.clientes.isNotEmpty && !DataStore.clientes.contains(clienteSeleccionado)) {
      clienteSeleccionado = DataStore.clientes.first;
    }

    List<Widget> itemsSeleccionadosWidgets = [];
    for (var prod in DataStore.productos) {
      int cant = cantidades[prod.id] ?? 0;
      if (cant > 0) {
        itemsSeleccionadosWidgets.add(
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              title: Text(prod.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("\$${prod.precio.toStringAsFixed(2)} c/u  |  Subtotal: \$${(cant * prod.precio).toStringAsFixed(2)}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => setState(() => cantidades[prod.id] = cant - 1),
                  ),
                  Text("$cant", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                    onPressed: () => setState(() => cantidades[prod.id] = cant + 1),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAlignment.start,
            children: [
              const Text('Cliente:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 5),
              DataStore.clientes.isEmpty
                  ? const Text('No hay clientes registrados', style: TextStyle(color: Colors.red))
                  : DropdownButton<Cliente>(
                      value: clienteSeleccionado,
                      isExpanded: true,
                      items: DataStore.clientes.map((c) {
                        return DropdownMenuItem(
                          value: c,
                          child: Text("${c.nombre} (${c.telefono})"),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => clienteSeleccionado = val),
                    ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _abrirCatalogoProductos,
                  icon: const Icon(Icons.list_alt, color: Colors.white),
                  label: const Text(
                    " + Agregar Productos al Pedido",
                    style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: itemsSeleccionadosWidgets.isEmpty
              ? const Center(
                  child: Text(
                    "Ningún producto agregado aún.\nPresiona '+ Agregar Productos al Pedido'.",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 15),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: itemsSeleccionadosWidgets,
                ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 5,
                offset: const Offset(0, -2),
              )
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[300]!),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("Pedido #${DataStore.numeroPedido.toString().padLeft(2, '0')}", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(
                      "TOTAL: \$${totalActual.toStringAsFixed(2)}",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green[800]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _enviarWhatsApp,
                  icon: const Icon(Icons.send, color: Colors.white),
                  label: const Text(
                    "Enviar Pedido por WhatsApp",
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==========================================
// PESTAÑA 2: HISTORIAL
// ==========================================
class PantallaHistorialPedidos extends StatefulWidget {
  const PantallaHistorialPedidos({super.key});

  @override
  State<PantallaHistorialPedidos> createState() => _PantallaHistorialPedidosState();
}

class _PantallaHistorialPedidosState extends State<PantallaHistorialPedidos> {
  void _editarPedidoModal(Pedido pedido) {
    Cliente clienteTemp = pedido.cliente;
    Map<String, int> cantidadesTemp = {};

    for (var item in pedido.items) {
      cantidadesTemp[item.producto.id] = item.cantidad;
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            double totalModal = 0;
            for (var prod in DataStore.productos) {
              int c = cantidadesTemp[prod.id] ?? 0;
              totalModal += c * prod.precio;
            }

            return AlertDialog(
              title: Text('Modificar Pedido #${pedido.numero}'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAlignment: CrossAlignment.start,
                    children: [
                      const Text('Cambiar Cliente:', style: TextStyle(fontWeight: FontWeight.bold)),
                      DropdownButton<Cliente>(
                        value: DataStore.clientes.contains(clienteTemp) ? clienteTemp : (DataStore.clientes.isNotEmpty ? DataStore.clientes.first : null),
                        isExpanded: true,
                        items: DataStore.clientes.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c.nombre));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setModalState(() => clienteTemp = val);
                        },
                      ),
                      const SizedBox(height: 15),
                      const Text('Modificar Productos:', style: TextStyle(fontWeight: FontWeight.bold)),
                      ...DataStore.productos.map((prod) {
                        int cant = cantidadesTemp[prod.id] ?? 0;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(prod.nombre, overflow: TextOverflow.ellipsis)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                                  onPressed: () {
                                    if (cant > 0) setModalState(() => cantidadesTemp[prod.id] = cant - 1);
                                  },
                                ),
                                Text('$cant'),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                                  onPressed: () => setModalState(() => cantidadesTemp[prod.id] = cant + 1),
                                ),
                              ],
                            )
                          ],
                        );
                      }),
                      const Divider(),
                      Text('Nuevo Total: \$${totalModal.toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[800])),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                ElevatedButton(
                  onPressed: () {
                    List<ItemPedido> nuevosItems = [];
                    for (var prod in DataStore.productos) {
                      int c = cantidadesTemp[prod.id] ?? 0;
                      if (c > 0) nuevosItems.add(ItemPedido(producto: prod, cantidad: c));
                    }

                    if (nuevosItems.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('El pedido no puede quedar sin productos')));
                      return;
                    }

                    setState(() {
                      pedido.cliente = clienteTemp;
                      pedido.items = nuevosItems;
                    });

                    Navigator.pop(context);
                  },
                  child: const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _reenviarWhatsApp(Pedido pedido) async {
    String detalleMsg = "";
    for (var item in pedido.items) {
      detalleMsg += "• ${item.cantidad}x ${item.producto.nombre}: \$${item.subtotal.toStringAsFixed(2)}\n";
    }

    final String mensaje = "Estimado/a ${pedido.cliente.nombre},\n\n"
        "📦 *Pedido #${pedido.numero} (Actualizado)*\n"
        "$detalleMsg\n"
        "💰 *Total:* \$${pedido.total.toStringAsFixed(2)}";

    final Uri url = Uri.parse("https://wa.me/${pedido.cliente.telefono}?text=${Uri.encodeComponent(mensaje)}");

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (DataStore.historialPedidos.isEmpty) {
      return const Center(child: Text("No se han generado pedidos aún."));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: DataStore.historialPedidos.length,
      itemBuilder: (context, i) {
        final ped = DataStore.historialPedidos[i];

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            title: Text("Pedido #${ped.numero} - ${ped.cliente.nombre}", style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text("Total: \$${ped.total.toStringAsFixed(2)}"),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _editarPedidoModal(ped)),
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => setState(() => DataStore.historialPedidos.removeAt(i))),
              ],
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAlignment: CrossAlignment.start,
                  children: [
                    Text("Teléfono: ${ped.cliente.telefono}"),
                    const SizedBox(height: 6),
                    const Text("Detalle:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ...ped.items.map((item) => Text("• ${item.cantidad}x ${item.producto.nombre} (\$${item.subtotal.toStringAsFixed(2)})")),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _reenviarWhatsApp(ped),
                        icon: const Icon(Icons.send, color: Color(0xFF25D366)),
                        label: const Text("Reenviar por WhatsApp", style: TextStyle(color: Color(0xFF25D366))),
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

// ==========================================
// PESTAÑA 3: CLIENTES
// ==========================================
class PantallaClientes extends StatefulWidget {
  const PantallaClientes({super.key});

  @override
  State<PantallaClientes> createState() => _PantallaClientesState();
}

class _PantallaClientesState extends State<PantallaClientes> {
  final nombreC = TextEditingController();
  final telC = TextEditingController();
  final masivoC = TextEditingController();

  void _mostrarModalAgregarCliente() {
    nombreC.clear();
    telC.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Nuevo Cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreC, decoration: const InputDecoration(labelText: 'Nombre Completo')),
            TextField(controller: telC, decoration: const InputDecoration(labelText: 'Teléfono')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (nombreC.text.isNotEmpty && telC.text.isNotEmpty) {
                setState(() {
                  DataStore.clientes.add(Cliente(id: DateTime.now().toString(), nombre: nombreC.text, telefono: telC.text));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          )
        ],
      ),
    );
  }

  void _mostrarModalMasivo() {
    masivoC.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cargar Lista Masiva de Clientes'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Pega varios contactos con el formato:\nNombre, Teléfono (uno por línea)',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: masivoC,
              maxLines: 6,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'María López, 50499887766\nCarlos Ruiz, 50488776655',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (masivoC.text.isNotEmpty) {
                List<String> lineas = masivoC.text.split('\n');
                int agregados = 0;
                setState(() {
                  for (var linea in lineas) {
                    if (linea.contains(',')) {
                      var partes = linea.split(',');
                      String n = partes[0].trim();
                      String t = partes[1].trim().replaceAll(RegExp(r'[^\d+]'), '');
                      if (n.isNotEmpty && t.isNotEmpty) {
                        DataStore.clientes.add(Cliente(id: DateTime.now().microsecondsSinceEpoch.toString(), nombre: n, telefono: t));
                        agregados++;
                      }
                    }
                  }
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Se agregaron $agregados clientes.')));
              }
            },
            child: const Text('Cargar Todos'),
          )
        ],
      ),
    );
  }

  void _editarClienteModal(Cliente cliente) {
    final editNombre = TextEditingController(text: cliente.nombre);
    final editTel = TextEditingController(text: cliente.telefono);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificar Cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: editNombre, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: editTel, decoration: const InputDecoration(labelText: 'Teléfono')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                cliente.nombre = editNombre.text;
                cliente.telefono = editTel.text;
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: Colors.red[50],
            child: ListTile(
              title: const Text("Contador Semanal", style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text("Siguiente Pedido: #${DataStore.numeroPedido.toString().padLeft(2, '0')}"),
              trailing: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => setState(() => DataStore.numeroPedido = 1),
                child: const Text("Reiniciar a 01", style: TextStyle(color: Colors.white)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
              onPressed: _mostrarModalMasivo,
              icon: const Icon(Icons.paste, color: Colors.blue),
              label: const Text("Cargar Lista Masiva de Clientes", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 15),

          if (DataStore.clientes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("No hay clientes guardados.")),
            )
          else
            ...DataStore.clientes.map((c) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.person, color: Colors.green),
                    title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Tel: ${c.telefono}"),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editarClienteModal(c);
                        } else if (value == 'delete') {
                          setState(() => DataStore.clientes.remove(c));
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Eliminar'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green[700],
        onPressed: _mostrarModalAgregarCliente,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Nuevo Cliente", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

// ==========================================
// PESTAÑA 4: PRODUCTOS
// ==========================================
class PantallaProductos extends StatefulWidget {
  const PantallaProductos({super.key});

  @override
  State<PantallaProductos> createState() => _PantallaProductosState();
}

class _PantallaProductosState extends State<PantallaProductos> {
  final prodC = TextEditingController();
  final precioC = TextEditingController();

  void _mostrarModalAgregarProducto() {
    prodC.clear();
    precioC.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar Nuevo Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: prodC, decoration: const InputDecoration(labelText: 'Nombre del Producto')),
            TextField(controller: precioC, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio (\$)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              if (prodC.text.isNotEmpty && precioC.text.isNotEmpty) {
                setState(() {
                  DataStore.productos.add(Producto(
                    id: DateTime.now().toString(),
                    nombre: prodC.text,
                    precio: double.tryParse(precioC.text) ?? 0.0,
                  ));
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Guardar'),
          )
        ],
      ),
    );
  }

  void _editarProductoModal(Producto producto) {
    final editNombre = TextEditingController(text: producto.nombre);
    final editPrecio = TextEditingController(text: producto.precio.toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificar Producto'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: editNombre, decoration: const InputDecoration(labelText: 'Nombre')),
            TextField(controller: editPrecio, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Precio (\$)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                producto.nombre = editNombre.text;
                producto.precio = double.tryParse(editPrecio.text) ?? producto.precio;
              });
              Navigator.pop(context);
            },
            child: const Text('Guardar Cambios'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (DataStore.productos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text("No hay productos guardados.")),
            )
          else
            ...DataStore.productos.map((p) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.shopping_bag, color: Colors.green),
                    title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Precio: \$${p.precio.toStringAsFixed(2)}"),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'edit') {
                          _editarProductoModal(p);
                        } else if (value == 'delete') {
                          setState(() => DataStore.productos.remove(p));
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(Icons.edit, color: Colors.blue, size: 20),
                              SizedBox(width: 8),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Eliminar'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.green[700],
        onPressed: _mostrarModalAgregarProducto,
        icon: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: const Text("Nuevo Producto", style: TextStyle(color: Colors.white)),
      ),
    );
  }
}
