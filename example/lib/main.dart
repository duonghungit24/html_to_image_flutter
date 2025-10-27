import 'dart:async';

import 'package:flutter/material.dart';
import 'package:html_to_image_flutter/html_to_image_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:universal_ble/universal_ble.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomnePage(),
    );
  }
}

class HomnePage extends StatefulWidget {
  const HomnePage({super.key});

  @override
  State<HomnePage> createState() => _HomnePageState();
}

class _HomnePageState extends State<HomnePage> {
  List<BluetoothInfo> list = [];
  String? connectedAddress;
  bool isConnecting = false;

  @override
  void initState() {
    super.initState();
    print("init home");
    // _loadBluetoothList();
  }

  Future<void> _loadBluetoothList() async {
    // try {
    //   final List<BluetoothInfo> listResult =
    //       await PrintBluetoothThermal.pairedBluetooths;
    //   print("listResult ${listResult.length}");
    //   setState(() {
    //     list = listResult;
    //   });
    // } catch (e) {
    //   print("Lỗi khi lấy danh sách Bluetooth: $e");
    // }
    isBluetoothOpen().then(
      (v) => {
        if (!mounted) {},
        if (v)
          {
            showBluetoothDevicesPopup(context, (BleDevice device) async {
              print("selected device: ${device.deviceId}");

              await printTest(device);
            }),
          },
      },
    );
  }

  static Future<bool> isBluetoothOpen() async {
    try {
      var status =
          await [
            Permission.bluetooth,
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            Permission.location,
          ].request();
      // if (status.values.every((i) => i == PermissionStatus.permanentlyDenied)) {
      //   openAppSettings();
      // }
      return status.values.any(
        (i) =>
            i == PermissionStatus.granted || i == PermissionStatus.provisional,
      );
    } catch (e) {
      return false;
    }
  }

  Future<void> connectToDevice(BluetoothInfo device) async {
    print("device ${device.toString()}");
    setState(() {
      isConnecting = true;
      connectedAddress = device.macAdress;
    });
    final bool result = await PrintBluetoothThermal.connect(
      macPrinterAddress: device.macAdress,
    );

    print("result ${result}");
    if (result) {
      setState(() {
        isConnecting = false;
        connectedAddress = device.macAdress;
      });
    } else {
      setState(() {
        isConnecting = false;
        connectedAddress = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Kết nối tới ${device.name} thành công!")),
      );
    }
  }

  Future<void> printTest(BleDevice device) async {
    // bool conecctionStatus = await PrintBluetoothThermal.connectionStatus;
    // if (conecctionStatus) {
    //   List<int> ticket = await testTicket();
    //   final result = await PrintBluetoothThermal.writeBytes(ticket);
    //   print("print result: $result");
    // } else {
    //   //no connected
    // }
    final bool result = await PrintBluetoothThermal.connect(
      macPrinterAddress: device.deviceId,
    );
    if (result) {
      List<int> ticket = await testTicket();
      final result = await PrintBluetoothThermal.writeBytes(ticket);
      print("print result: $result");
    }
  }

  Future<List<int>> testTicket() async {
    List<int> bytes = [];
    final imageBytes = await HtmlToImage.convertToImageFromAsset(
      asset: 'assets/icons/test.html',
      width: 384,
    );
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm58, profile);
    // final ByteData data = await rootBundle.load('assets/icons/test.jpg');
    // final Uint8List bytesImg = data.buffer.asUint8List();

    final grayscaleImage = img.grayscale(img.decodeImage(imageBytes)!);
    final optimizedImage = _optimizeImageForThermalPrint(
      grayscaleImage,
      PaperSize.mm58.width,
    );

    bytes += generator.setStyles(
      const PosStyles(
        align: PosAlign.center,
        fontType: PosFontType.fontB,
        bold: true,
        height: PosTextSize.size1,
        width: PosTextSize.size1,
      ),
    );
    bytes += generator.imageRaster(optimizedImage);
    generator.feed(2);
    bytes += generator.cut();
    return bytes;
  }

  static img.Image _optimizeImageForThermalPrint(
    img.Image originalImage,
    int printerWidth,
  ) {
    img.Image processedImage = originalImage;

    // Resize với chiều cao tự động tính toán
    final targetHeight =
        (originalImage.height * printerWidth / originalImage.width).round();

    processedImage = img.copyResize(
      originalImage,
      width: printerWidth,
      height: targetHeight,
      interpolation: img.Interpolation.cubic,
    );

    // Grayscale và contrast
    processedImage = img.grayscale(processedImage);
    processedImage = img.contrast(processedImage, contrast: 40);

    return processedImage;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _loadBluetoothList,
        child: const Icon(Icons.refresh),
      ),
      appBar: AppBar(title: const Text('Home Screen')),
      body: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, index) {
          final device = list[index];
          final isConnected = connectedAddress == device.macAdress;

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    leading: const Icon(Icons.print, color: Colors.blueAccent),
                    title: Text(device.name),
                    subtitle: Text(device.macAdress),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            isConnected ? Colors.green : Colors.blue,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed:
                          isConnecting ? null : () => connectToDevice(device),
                      child:
                          isConnecting && connectedAddress == device.macAdress
                              ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                              : Text(isConnected ? "Đã kết nối" : "Kết nối"),
                    ),
                  ),
                  if (isConnected)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0, left: 8),
                      child: Row(
                        children: [
                          // ElevatedButton.icon(
                          //   onPressed: printTest,
                          //   style: ElevatedButton.styleFrom(
                          //     backgroundColor: Colors.orangeAccent,
                          //     shape: RoundedRectangleBorder(
                          //       borderRadius: BorderRadius.circular(8),
                          //     ),
                          //   ),
                          //   icon: const Icon(Icons.print, color: Colors.white),
                          //   label: const Text(
                          //     "In thử",
                          //     style: TextStyle(color: Colors.white),
                          //   ),
                          // ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() => connectedAddress = null);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    "Đã ngắt kết nối ${device.name}",
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(
                              Icons.link_off,
                              color: Colors.white,
                            ),
                            label: const Text(
                              "Ngắt kết nối",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

Future<void> showBluetoothDevicesPopup(
  BuildContext context,
  void Function(BleDevice)? onSelectPrinter,
) async {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) {
      return BluetoothDevicesPopup(onSelectPrinter: onSelectPrinter);
    },
  );
}

class BluetoothDevicesPopup extends StatefulWidget {
  const BluetoothDevicesPopup({super.key, this.onSelectPrinter});

  final void Function(BleDevice)? onSelectPrinter;

  @override
  State<BluetoothDevicesPopup> createState() => _BluetoothDevicesPopupState();
}

class _BluetoothDevicesPopupState extends State<BluetoothDevicesPopup> {
  bool _isLoading = false;
  StreamSubscription<BleDevice>? _stream;
  final List<BleDevice> _devices = [];
  BleDevice? _connectedDevice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => startScan());
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  void stop() {
    UniversalBle.stopScan();
    _stream?.cancel();
  }

  void startScan() async {
    try {
      _devices.clear();

      _isLoading = true;

      if (mounted) setState(() {});
      final systemDevices = await UniversalBle.getSystemDevices(
        withServices: [],
      );
      _connectedDevice = systemDevices.firstOrNull;
      _devices.addAll(systemDevices);
      _isLoading = systemDevices.isEmpty;
      if (mounted) setState(() {});

      _stream?.cancel();
      _stream = UniversalBle.scanStream.listen((result) {
        if ((result.name ?? '').isEmpty) return;
        print("${result.services}");
        int index = _devices.indexWhere((e) => e.deviceId == result.deviceId);
        if (index == -1) {
          _devices.add(result);
        } else {
          if (result.name == null && _devices[index].name != null) {
            result.name = _devices[index].name;
          }
          _devices[index] = result;
        }
        _isLoading = false;
        if (mounted) setState(() {});
      });

      await UniversalBle.startScan();

      // stop after a few seconds
      Future.delayed(const Duration(seconds: 10), stop);
    } catch (e) {
      debugPrint("BLE scan error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _connectPrinter(BleDevice printer) async {
    try {
      if (_isLoading) return;
      setState(() {
        _isLoading = true;
        _connectedDevice = printer;
      });
      await UniversalBle.connect(printer.deviceId);

      if (!mounted) return;
      setState(() => _isLoading = false);
      setState(() => _connectedDevice = printer);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Kết nối  thành công!")));
    } catch (_) {
      setState(() => _isLoading = false);
      setState(() => _connectedDevice = null);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Kết nối  that bai!")));
    }
  }

  void _disconnectPrinter(BleDevice printer) {
    UniversalBle.disconnect(printer.deviceId);
    setState(() => _connectedDevice = null);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("ngat Kết nối  thành công!")));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      title:
          _isLoading
              ? null
              : InkWell(
                onTap: startScan,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.refresh, color: Colors.black),
                ),
              ),
      content: SizedBox(
        width: 400,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: 200,
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child:
                  _devices.isEmpty && !_isLoading
                      ? Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(child: Text('chua co thong tin')),
                      )
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: _devices.length,
                        itemBuilder:
                            (_, i) => _buildPrinterCard(_devices[i], context),
                      ),
            ),
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.white70,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 4,
                      color: Colors.blue,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterCard(BleDevice printer, BuildContext context) {
    final isConnected =
        _connectedDevice != null &&
        _connectedDevice?.deviceId == printer.deviceId;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Colors.cyan,
      elevation: 0,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              dense: true,
              leading: Icon(Icons.print, color: Colors.blueAccent),
              title: Text(printer.name ?? ''),
              subtitle: Text(printer.deviceId),
              contentPadding: EdgeInsets.zero,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed:
                        _isLoading ? null : () => _connectPrinter(printer),

                    child:
                        _isLoading && _connectedDevice == printer
                            ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                            : Text(isConnected ? 'da ket noi' : 'ket noi'),
                  ),
                ],
              ),
            ),
            if (isConnected)
              Padding(
                padding: EdgeInsets.only(top: 8, left: 8),
                child: Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed:
                          () => {
                            Navigator.of(context).pop(),
                            widget.onSelectPrinter?.call(printer),
                          },
                      icon: const Icon(Icons.print, color: Colors.white),
                      label: Text('in', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orangeAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _disconnectPrinter(printer),
                      icon: const Icon(Icons.link_off, color: Colors.white),
                      label: Text(
                        "Ngat ket noi",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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
}
