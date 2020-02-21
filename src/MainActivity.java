package com.example.test;

import android.util.Log;
import android.view.View;
import android.os.Bundle;
import android.widget.*;

import androidx.activity.*;

public class MainActivity extends ComponentActivity {
	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);

		//layout = (RelativeLayout)RelativeLayout.inflate(this, R.layout.activity_main, null);
		setContentView(R.layout.activity_main);
	}
}
