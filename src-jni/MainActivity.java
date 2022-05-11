package com.example.test;

import android.os.Bundle;
import android.app.Activity;
import android.widget.TextView;

public class MainActivity extends Activity {
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.activity_main);

		((TextView)findViewById(R.id.hello_tv)).setText(getHelloString());
	}

	private native String getHelloString();

	static {
		System.loadLibrary("jni-example");
	}
}
