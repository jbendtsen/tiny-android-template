#include <jni.h>

JNIEXPORT jstring JNICALL
Java_com_example_test_MainActivity_getHelloString(JNIEnv *env, jobject obj) {
	return (*env)->NewStringUTF(env, "Hello! This string came from native code!");
}
