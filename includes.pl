# Roughly arranged in descending order of how likely you'll need to change each value
# Note that windows users need to install a bash terminal for the scripts to run. Git-Bash is a good option, as it comes bundled with git.

$ANDROID_VERSION = "13";
$SDK_DIR = "C:/Android/sdk";
$KOTLIN_LIB_DIR = "/usr/share/kotlin/lib";

$MIN_SDK_VERSION = 15;

$REPO = "https://dl.google.com/dl/android/maven2";

$KEYSTORE = "keystore.jks";
$KS_PASS = "123456";

$TOOLS_DIR = "$SDK_DIR/android-$ANDROID_VERSION";
$PLATFORM_DIR = "$SDK_DIR/android-$ANDROID_VERSION";

$PKG_OUTPUT = "lib";
$LIB_RES_DIR = "$PKG_OUTPUT/res";
$LIB_CLASS_DIR = "$PKG_OUTPUT/classes";

$JAR_TOOLS = "java -Xmx1024M -Xss1m -jar $TOOLS_DIR/lib";

$CMD_7Z = "7z";
$CMD_JAR = "jar";
$CMD_JAVA = "java";
$CMD_JAVAC = "javac";
$CMD_KOTLINC = "kotlinc";
$CMD_ADB = "$SDK_DIR/platform-tools/adb";
$CMD_D8 = "$CMD_JAVA -Xmx1024M -Xss1m -cp $TOOLS_DIR/lib/d8.jar com.android.tools.r8.D8";