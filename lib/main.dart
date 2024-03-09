import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:m_widget/m_widget.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await MWidget.initialize(
    defaultLanguage: LanguageType.indonesiaIndonesian,
    defaultTheme: ThemeValue(
      useDynamicColors: true,
    ),
  );

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) => MWidgetDynamicColorBuilder(
        builder: (context, theme, darkTheme, themeMode, colorScheme) => MaterialApp(
          title: 'Coffe Bean Classification',
          home: const Homepage(),
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: scaffoldMessengerKey,
          theme: theme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          debugShowCheckedModeBanner: false,
        ),
      );
}

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String currentValue = 'assets/light:assets/images/light.png';

  (List<List<double>>, String)? output;

  Future<(List<List<double>>, String)?> runModel(String value) async {
    try {
      late Uint8List data;
      if (value.contains('Your image')) {
        data = Uint8List.fromList((jsonDecode(value.split(':')[1]) as List).cast<int>());
      } else {
        // Load image from assets
        ByteData byteData = await rootBundle.load(value.split(':')[1]);
        data = byteData.buffer.asUint8List();
      }
      img.Image? image = img.decodeImage(data);

      if (image != null) {
        // Resize the image to the input size of the model
        img.Image resizedImage = img.copyResize(image, width: 224, height: 224);

        // Convert image to a byte list
        var imageBytes = resizedImage.getBytes();

        // Create a Float32List and fill it with normalized pixel values
        var imageSize = 224 * 224 * 3;
        List inputImage = Float32List(imageSize);
        for (int i = 0; i < imageSize; i++) {
          inputImage[i] = imageBytes[i] / 255.0; // Normalization
        }

        // Reshape the input as per the model requirements
        inputImage = inputImage.reshape([1, 224, 224, 3]);

        // Prepare the output tensor
        List output = List.filled(1 * 4, 0).reshape([1, 4]);

        // Create interpreter from asset
        Interpreter interpreter = await Interpreter.fromAsset('assets/models/coffe_bean_detector.tflite');

        // Run the model using the interpreter
        interpreter.run(inputImage, output);

        // Close the interpreter when done
        interpreter.close();

        // Define the mapping from index to label
        List<String> labels = ['Dark', 'Green', 'Light', 'Medium'];

        List<double> outputProbabilities = output[0].cast<double>();

        // Find the index of the maximum value in the output probabilities
        int highestProbIndex = outputProbabilities.indexWhere((prob) => prob == outputProbabilities.reduce(max));

        // Convert the index to the corresponding text label
        String predictedLabel = labels[highestProbIndex];

        debugPrint('Output : ${output.toString()}, $predictedLabel');

        return (output.cast<List<double>>(), predictedLabel);
      }
    } catch (e) {
      showErrorDialog(e.toString());
      rethrow;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Coffe Bean Classification'),
        ),
        body: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          children: [
            Text(
              'Assets',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            GridChoice(
              data: List.generate(
                5,
                (index) => GridChoiceData(
                  value: [
                    'assets/light:assets/images/light.png',
                    'assets/light-medium:assets/images/light-medium.png',
                    'assets/medium:assets/images/medium.png',
                    'assets/medium-dark:assets/images/medium-dark.png',
                    'assets/dark:assets/images/dark.png',
                  ][index],
                  label: [
                    'Light',
                    'Light-Medium',
                    'Medium',
                    'Medium-Dark',
                    'Dark',
                  ][index],
                  image: AssetImage(
                    'assets/images/${[
                      'light',
                      'light-medium',
                      'medium',
                      'medium-dark',
                      'dark',
                    ][index]}.png',
                  ),
                ),
              ),
              groupValue: currentValue,
              onTap: (value) => setState(() => currentValue = value),
            ),
            const Divider(),
            Text(
              'Assets/test',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            GridChoice(
              data: List.generate(
                4,
                (index) => GridChoiceData(
                  value: [
                    'assets/test/green:assets/images/test/green (1).png',
                    'assets/test/light:assets/images/test/light (1).png',
                    'assets/test/medium:assets/images/test/medium (1).png',
                    'assets/test/dark:assets/images/test/dark (1).png',
                  ][index],
                  label: [
                    'Green',
                    'Light',
                    'Medium',
                    'Dark',
                  ][index],
                  image: AssetImage(
                    'assets/images/test/${[
                      'green',
                      'light',
                      'medium',
                      'dark',
                    ][index]} (1).png',
                  ),
                ),
              ),
              groupValue: currentValue,
              onTap: (value) => setState(() => currentValue = value),
            ),
            const Divider(),
            Text(
              'Your image 😁',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            GridChoice.withImage(
              groupValue: currentValue,
              value: 'Your image',
              onTap: (value) => setState(() => currentValue = value),
            ),
            const Divider(),
            Text('Output: ${output.toString()}'),
            const SizedBox(height: 8.0),
            FilledButton(
              onPressed: () => runModel(currentValue).then((value) => setState(() => output = value)),
              child: const Text('Test'),
            ),
            const SizedBox(height: 20.0),
          ],
        ),
      );
}

class GridChoice extends StatefulWidget {
  const GridChoice({
    super.key,
    required this.data,
    required this.groupValue,
    this.onTap,
  })  : value = '',
        _withImage = false;

  GridChoice.withImage({
    super.key,
    required this.value,
    required this.groupValue,
    this.onTap,
  })  : data = [],
        _withImage = true;

  final List<GridChoiceData> data;
  final String value;
  final String groupValue;
  final void Function(String value)? onTap;
  final bool _withImage;

  @override
  State<GridChoice> createState() => _GridChoiceState();
}

class _GridChoiceState extends State<GridChoice> {
  Uint8List? _imageData;

  @override
  Widget build(BuildContext context) => GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: ((MediaQuery.sizeOf(context).width - 8.0) / 3) / 200.0,
        ),
        shrinkWrap: true,
        primary: false,
        itemBuilder: (context, index) {
          GridChoiceData? data = widget._withImage ? null : widget.data[index];

          return Padding(
            padding: const EdgeInsets.all(8.0),
            child: Stack(
              children: [
                Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: (widget._withImage && _imageData == null) || (widget._withImage && _imageData != null && index == 1) || (widget._withImage && _imageData == null && index == 0) ? Theme.of(context).colorScheme.primary : null,
                          borderRadius: BorderRadius.circular(8.0),
                          image: (widget._withImage && _imageData == null) || (widget._withImage && _imageData != null && index == 1) || (widget._withImage && _imageData == null && index == 0)
                              ? null
                              : DecorationImage(
                                  image: widget._withImage && _imageData != null ? MemoryImage(_imageData!) : data!.image,
                                  fit: BoxFit.cover,
                                ),
                        ),
                        child: (widget._withImage && _imageData == null && index == 1) || (widget._withImage && _imageData != null && index == 0) || (!widget._withImage) ? null : const Center(child: Icon(Icons.camera_alt)),
                      ),
                    ),
                    if (!widget._withImage) Text(data!.label),
                  ],
                ),
                if ((widget._withImage && _imageData == null && index == 1) || (widget._withImage && _imageData != null && index == 0) || (!widget._withImage))
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.black,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.transparent,
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                if ((widget._withImage && _imageData != null) || (widget._withImage && _imageData == null && index == 1) || (widget._withImage && _imageData != null && index == 0) || (!widget._withImage))
                  Positioned(
                    left: 4.0,
                    top: 4.0,
                    child: ((data?.value ?? '${widget.value}:$_imageData') == widget.groupValue)
                        ? Icon(
                            Icons.radio_button_checked,
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : Icon(
                            Icons.radio_button_off,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                  ),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8.0),
                    onTap: () => (widget._withImage && _imageData == null) || (widget._withImage && _imageData != null && index == 1) || (widget._withImage && _imageData == null && index == 0)
                        ? ImageContainer.handleChangeImage(
                            sheetTitleText: 'Pilih Gambar',
                            showDelete: false,
                          ).then((value) async {
                            if (value.image == null) return;

                            _imageData = await value.image!.readAsBytes();

                            setState(() {});
                          })
                        : widget.onTap?.call(data?.value ?? '${widget.value}:$_imageData'),
                  ),
                ),
              ],
            ),
          );
        },
        itemCount: widget._withImage ? (_imageData != null ? 2 : 1) : widget.data.length,
      );
}

@immutable
class GridChoiceData {
  const GridChoiceData({
    required this.value,
    required this.label,
    required this.image,
  });

  final String value;
  final String label;
  final ImageProvider image;
}
