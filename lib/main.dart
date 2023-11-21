import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';


// 비동기 함수로.. => firebase 때문인 듯
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.pinkAccent),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late Record audioRecord;
  late AudioPlayer audioPlayer;
  bool isRecording = false;
  String audioPath = '';
  final dateTimeNow = DateTime.now();
  final formatter = DateFormat('yyyy-MM-dd-HH-mm-ss');

  @override
  void initState() {
    audioPlayer = AudioPlayer();
    audioRecord = Record();
    super.initState();
  }

  @override
  void dispose() {
    audioRecord.dispose();
    audioPlayer.dispose();
    super.dispose();
  }

  Future<void> startRecording() async {
    try {
      if (await audioRecord.hasPermission()) {
        await audioRecord.start();
        setState(() {
          isRecording = true;
        });
      }
    } catch (e) {
      print('[Error] Start Recording: $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      String? path = await audioRecord.stop();
      setState(() {
        isRecording = false;
        audioPath = path!;
      });
    } catch (e) {
      print('[Error] Stop Recording: $e');
    }
  }

  Future<void> playRecording() async{
    //if (audioPath.isNotEmpty) {
    try {
      Source urlSource = UrlSource(audioPath);
      await audioPlayer.play(urlSource);
    }
    catch (e) {
      print('[Error] Playing Recording : $e');
    }
    //}
  }

  Future<void> uploadFile() async {
    try {
      final formattedDateTime = formatter.format(dateTimeNow);
      final path = 'files/$formattedDateTime.mp3';

      final file = File(audioPath);

      final ref = FirebaseStorage.instance.ref().child(path);
      await ref.putFile(file);

      print("File uploaded successfully");
    } catch (e) {
      print("Error during file upload: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('녹음 기능 구현2'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            ElevatedButton(
                onPressed: uploadFile, // 버튼 클릭 시 경로 출력
                child: Text('firebase_storage')),
            if (isRecording)
              const Text(
                'Recording in Progress',
                style: TextStyle(
                  fontSize: 20,
                ),
              ),
            ElevatedButton(
              onPressed: isRecording ? stopRecording : startRecording,
              child: isRecording
                  ? const Text('Send your today story')
                  : const Text('Start to speak your today story')
            ),
            const SizedBox(
              height: 25,
            ),
            if (!isRecording && audioPath != null)
              ElevatedButton(
                onPressed: playRecording,
                child: Text('Communicate with 아이'),
              ),
          ],
        ),
      ),
    );
  }
}
