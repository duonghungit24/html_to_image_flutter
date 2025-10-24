import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:html_to_image_flutter/html_to_image_flutter.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:image/image.dart' as img;
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';

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
    _loadBluetoothList();
  }

  Future<void> _loadBluetoothList() async {
    try {
      final List<BluetoothInfo> listResult =
          await PrintBluetoothThermal.pairedBluetooths;

      setState(() {
        list = listResult;
      });
    } catch (e) {
      print("Lỗi khi lấy danh sách Bluetooth: $e");
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

  Future<void> printTest() async {
    bool conecctionStatus = await PrintBluetoothThermal.connectionStatus;
    if (conecctionStatus) {
      List<int> ticket = await testTicket();
      final result = await PrintBluetoothThermal.writeBytes(ticket);
      print("print result: $result");
    } else {
      //no connected
    }
  }

  Future<List<int>> testTicket() async {
    List<int> bytes = [];
    final imageBytes = await HtmlToImage.convertToImageFromAsset(
      asset: 'assets/icons/test.html',
      width: 384,
    );
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    // final ByteData data = await rootBundle.load('assets/icons/test.jpg');
    // final Uint8List bytesImg = data.buffer.asUint8List();

    final grayscaleImage = img.grayscale(img.decodeImage(imageBytes)!);
    final optimizedImage = _optimizeImageForThermalPrint(
      grayscaleImage,
      PaperSize.mm80.width,
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
                          ElevatedButton.icon(
                            onPressed: printTest,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orangeAccent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            icon: const Icon(Icons.print, color: Colors.white),
                            label: const Text(
                              "In thử",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
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
