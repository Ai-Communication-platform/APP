import 'dart:io';
import 'dart:ui';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/material.dart';
import 'package:loading_btn/loading_btn.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:rive/rive.dart';
import '';

// 비동기 함수로.. => firebase 때문인 듯
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await FirebaseAppCheck.instance.activate(
    webProvider: ReCaptchaV3Provider('recaptcha-v3-site-key'),
  );
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

      // 파일 업로드 후 15초 대기
      await Future.delayed(Duration(seconds: 12));

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
          String audioUrl = await result.items.last.getDownloadURL();

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
      backgroundColor: Colors.white,
      /*
      appBar: AppBar(
        backgroundColor: Theme
            .of(context)
            .colorScheme
            .inversePrimary,
        title: Text('녹음 기능 구현'),
      ),*/
      body: SingleChildScrollView(
        // SingleChildScrollView 추가
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
            // 중간
            RiveAnimation.asset('asset/shapes.riv'),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                child: Column(
                  children: [
                    Divider(
                      // 상단에 위치하는 Divider 위젯
                      color: const Color(0xFFFFCD4A),
                      thickness: 3.0,
                      height: 2, // 선과 이미지 사이의 거리를 줄임
                    ),
                    Row(
                      // 이미지들을 나타내는 Row 위젯
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Image.asset(
                          'asset/smaile 2.png',
                          width: 75.0,
                          height: 100.0,
                        ),
                        Image.asset(
                          'asset/font 1.png',
                          width: 150.0,
                          height: 100.0,
                        ),
                      ],
                    ),
                    Divider(
                      // 하단에 위치하는 Divider 위젯
                      color: const Color(0xFFFFCD4A),
                      thickness: 3.0,
                      height: 18, // 선과 이미지 사이의 거리를 줄임
                    ),
                    // 여기에 추가적인 위젯들을 배치할 수 있습니다.
                    Container(
                      alignment: Alignment(-1.0, -1.0),
                      child: Image.asset(
                        "asset/font 2.png",
                        width: 250,
                        height: 53,
                        fit: BoxFit.fill,
                      ),
                    ),
                    Container(margin: EdgeInsets.symmetric(vertical: 540),
                        child: Divider(color: const Color(0xFFFFCD4A), thickness: 3.0))
                  ],
                ),
              ),
            )
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.all(6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Container(
              width: 60,
              height: 60,
              child: FloatingActionButton(
                  backgroundColor: Colors.white,
                  onPressed: isRecording ? stopRecording : startRecording,
                  child: isRecording
                      ? Icon(
                          Icons.mic_off,
                          color: const Color(0xFFFF6969),
                        )
                      : Icon(
                          Icons.mic,
                          color: const Color(0xFFFF6969),
                        )),
            ),
            SizedBox(width: 10), // 버튼 사이의 간격
            Expanded(
              child: LoadingBtn(
                height: 50,
                borderRadius: 8,
                animate: true,
                color: const Color(0xFFFF6969),
                width: MediaQuery.of(context).size.width * 0.45,
                child: Text("소통하기",
                    style: TextStyle(fontSize: 22, color: Colors.white)),
                loader: Container(
                  padding: const EdgeInsets.all(10),
                  width: 40,
                  height: 40,
                  child: const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                onTap: ((startLoading, stopLoading, btnState) async {
                  if (btnState == ButtonState.idle && !isRecording) {
                    startLoading();
                    await Future.delayed(const Duration(seconds: 5));
                    await RecordUploadAndPlay();
                    stopLoading();
                  }
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
