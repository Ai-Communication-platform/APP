import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:firebase_app_check/firebase_app_check.dart';


// 비동기 함수로.. => firebase 때문인 듯
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),);
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
  late DateTime dateTimeNow; // late 키워드 사용
  final formatter = DateFormat('yyyy-MM-dd-HH-mm-ss');
  String file_path = '';

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
        file_path = audioPath;
        dateTimeNow = DateTime.now(); // 각 녹음마다 날짜와 시간을 갱신
      });
    } catch (e) {
      print('[Error] Stop Recording: $e');
    }
  }

  Future<void> playRecording() async{
    //if (audioPath.isNotEmpty) {
    try {
      Source urlSource = UrlSource(audioPath);
      file_path = audioPath;
      await audioPlayer.play(urlSource);
    }
    catch (e) {
      print('[Error] Playing Recording : $e');
    }
    //}
  }

  Future<void> uploadFile() async {
    try {
      final file = File(file_path);
      if (!file.existsSync()) {
        print('File does not exist: $file_path');
        return;
      }

      final formattedDateTime = formatter.format(dateTimeNow);
      final path = 'files/$formattedDateTime.mp3';
      final ref = FirebaseStorage.instance.ref().child(path);
      final UploadTask uploadTask = ref.putFile(file);

      await uploadTask.whenComplete(() {
        print("File uploaded successfully");
      }).catchError((e) {
        print("Error during file upload: $e");
      });
    } catch (e) {
      print("Error during file upload: $e");
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('녹음 기능 구현'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
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
            const SizedBox(
              height: 25,
            ),
            if (!isRecording && audioPath != null)
            ElevatedButton(
                onPressed: uploadFile, // 버튼 클릭 시 경로 출력
                child: Text('firebase_storage')),

          ],
        ),
      ),
    );
  }
}
