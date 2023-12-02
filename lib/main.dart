import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:loading_btn/loading_btn.dart';
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
  bool isPlaying = false; // 현재 오디오 재생 여부를 추적하는 변수
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
      if (await audioRecord.hasPermission() && !isPlaying) {
        await audioRecord.start();
        setState(() {
          isRecording = true;
        });
      }
    } catch (e) {
      print('[Error] Start Recording: $e');
    }
  }

  // Stop + upload_file + play_recent_file
  Future<void> RecordUploadAndPlay() async {
    try {
      // Firebase에 파일 업로드하고 완료될 때까지 기다림
      await uploadFile();

      // 파일 업로드 완료 후, 가장 최근 파일 재생
      await playRecentRecording();
    } catch (e) {
      print('[Error] During stopRecordUploadAndPlay: $e');
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


  Future<void> playRecentRecording() async {
    const int maxAttempts = 10;
    const int delayBetweenAttempts = 5000;

    try {
      // 이미 재생 중인 오디오가 있는지 확인
      if (isPlaying) {
        print('An audio is already playing.');
        return;
      }

      for (int attempts = 0; attempts < maxAttempts; attempts++) {
        ListResult result = await firebase_storage.FirebaseStorage.instance
            .ref('output/')
            .listAll();

        if (result.items.isNotEmpty) {
          result.items.sort((a, b) => b.name.compareTo(a.name));
          String audioUrl = await result.items.first.getDownloadURL();

          // 오디오 재생을 시작하고, isPlaying을 true로 설정
          isPlaying = true;
          await audioPlayer.play(UrlSource(audioUrl));
          isPlaying = false; // 재생이 완료되면 isPlaying을 false로 설정
          return; // 파일이 있으면 재생 후 함수 종료
        } else {
          // 파일이 없으면 일정 시간 대기 후 재시도
          await Future.delayed(Duration(milliseconds: delayBetweenAttempts));
        }
      }

      print('No files found in Firebase Storage after multiple attempts.');
    } catch (e) {
      print('[Error] Playing Recent Recording: $e');
      isPlaying = false; // 오류 발생 시 isPlaying을 false로 설정
    }
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
            LoadingBtn(
              height: 50,
              borderRadius: 8,
              animate: true,
              color: const Color(0xFFFF6969),
              width: MediaQuery.of(context).size.width * 0.45,
              child: Text("소통하기", style: TextStyle(fontFamily: 'nanum', fontSize: 22, color: Colors.white)),
              loader: Container(
                padding: const EdgeInsets.all(10),
                width: 40,
                height: 40,
                child: const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              onTap: ((startLoading, stopLoading, btnState) async{
                if(btnState == ButtonState.idle && !isRecording){
                  startLoading();
                  await Future.delayed(const Duration(seconds: 5));
                  await RecordUploadAndPlay();
                  stopLoading();
                }
              }),
            ),
          ],
        ),
      ),
    );
  }
}