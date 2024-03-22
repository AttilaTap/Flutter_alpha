import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Wrap MaterialApp with MediaQuery
    return MediaQuery(
      // Set alwaysUse24HourFormat to true
      data: MediaQueryData(alwaysUse24HourFormat: true),
      child: MaterialApp(
        title: 'Photo Gallery',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WidgetsBindingObserver {
  List<File> _allImages = []; // Maintain a separate list for all images
  List<File> _filteredImages = []; // Maintain a list for filtered images
  TimeOfDay _startTime = TimeOfDay(hour: 0, minute: 0); // Default start time
  TimeOfDay _endTime = TimeOfDay(hour: 0, minute: 0); // Default end time

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchImages();
    _startPeriodicTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // App is resumed, refresh the images
      _fetchImages();
    }
  }

  void _fetchImages() async {
    bool permissionGranted = false;
    if (Platform.isAndroid && await Permission.photos.isPermanentlyDenied) {
      openAppSettings(); // If permission is permanently denied, open app settings
    } else {
      var status = await Permission.photos
          .request(); // Use Permission.photos for gallery access
      permissionGranted = status.isGranted;
    }

    if (permissionGranted) {
      List<File> images = [];
      try {
        final result = await MethodChannel('com.example.app/gallery')
            .invokeMethod('getImages');
        for (String path in List.from(result)) {
          images.add(File(path));
        }
      } on PlatformException catch (e) {
        print("Failed to get images: '${e.message}'.");
      }
      setState(() {
        _allImages = images;
        _filteredImages = List.from(_allImages);
      });
      _filterImagesByTime();
    } else {
      print('Permission denied');
    }
  }

  void _startPeriodicTimer() {
    Timer.periodic(Duration(minutes: 5), (Timer timer) {
      _fetchImages();
    });
  }

  void _filterImagesByTime() {
    final now = DateTime.now();
    final startDateTime = DateTime(
        now.year, now.month, now.day, _startTime.hour, _startTime.minute);
    final endDateTime =
        DateTime(now.year, now.month, now.day, _endTime.hour, _endTime.minute);

    setState(() {
      _filteredImages = _allImages.where((image) {
        final imageDateTime = File(image.path).lastModifiedSync();
        return imageDateTime.isAfter(startDateTime) &&
            imageDateTime.isBefore(endDateTime);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Photo Gallery'),
      ),
      body: Column(
        children: [
          Text('Select Time Range:'),
          Row(
            children: [
              TextButton(
                onPressed: () async {
                  final selectedTime = await showTimePicker(
                    context: context,
                    initialTime: _startTime,
                  );
                  if (selectedTime != null) {
                    setState(() {
                      _startTime = selectedTime;
                    });
                    _filterImagesByTime(); // Apply time range filter when start time is changed
                  }
                },
                child: Text('Start Time: ${_startTime.format(context)}'),
              ),
              TextButton(
                onPressed: () async {
                  final selectedTime = await showTimePicker(
                    context: context,
                    initialTime: _endTime,
                  );
                  if (selectedTime != null) {
                    setState(() {
                      _endTime = selectedTime;
                    });
                    _filterImagesByTime(); // Apply time range filter when end time is changed
                  }
                },
                child: Text('End Time: ${_endTime.format(context)}'),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text('Number of Images Found: ${_filteredImages.length}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StaggeredGridView.countBuilder(
              crossAxisCount: 4,
              itemCount: _filteredImages.length, // Use filtered images list
              itemBuilder: (BuildContext context, int index) => Container(
                decoration: BoxDecoration(
                  image: DecorationImage(
                    image: FileImage(
                        _filteredImages[index]), // Use filtered images
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              staggeredTileBuilder: (int index) =>
                  StaggeredTile.count(2, index.isEven ? 2 : 1),
              mainAxisSpacing: 4.0,
              crossAxisSpacing: 4.0,
            ),
          ),
        ],
      ),
    );
  }
}

extension TimeOfDayExtension on TimeOfDay {
  String format(BuildContext context) =>
      MaterialLocalizations.of(context).formatTimeOfDay(this);
}
