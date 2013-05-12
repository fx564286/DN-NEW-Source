/*
 * DreamNarae, Emotional Android Tools.
    Copyright (C) 2013 Seo, Dong-Gil in Angeloid Team. 

 This code is dual-licensed under the terms of the Apache License Version 2.0 and
    the terms of the General Public License (GPL) Version 2.
    You may use this code according to either of these licenses as is most appropriate
    for your project on a case-by-case basis.

    The terms of each license can be found in the root directory of this project's repository as well as at:

    * http://www.apache.org/licenses/LICENSE-2.0
    * http://www.gnu.org/licenses/gpl-2.0.txt
 
    Unless required by applicable law or agreed to in writing, software
    distributed under these Licenses is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See each License for the specific language governing permissions and
    limitations under that License.


    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
	
	Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
 */
package angeloid.dreamnarae;

import java.util.ArrayList;
import java.util.Hashtable;
import java.util.Map;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.AlertDialog.Builder;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.PackageManager.NameNotFoundException;
import android.graphics.Color;
import android.net.Uri;
import android.os.Bundle;
import android.view.KeyEvent;
import android.view.View;
import android.widget.Button;
import android.widget.TextView;

public class Settings extends Activity {

	// Layout
	TextView LayoutTitle;
	TextView setting3_title;
	TextView setting4_title;
	TextView setting3_summary;
	TextView setting4_summary;
	Button go1;
	Button go2;
	TextView LayoutTitle2;

	// Slide Menu
	Button main;
	Button update;
	Button spica;
	Button pure;
	Button save;
	Button prev;
	Button miracle;
	Button brand;
	Button spisave;
	Button delete;
	Button promoting;
	Button setting;
	Button developerinfo;
	Button donate;

	// Kakao Link / Story Link
	private String encoding = "UTF-8";

	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		setContentView(R.layout.settings);
		
		LayoutTitle2 = (TextView) findViewById(R.id.tabtextview2);
		LayoutTitle2.setTypeface(MainActivity.Font);

		// Layout
		LayoutTitle = (TextView) findViewById(R.id.tabtextview);
		LayoutTitle.setTypeface(MainActivity.Font);
		setting3_title = (TextView) findViewById(R.id.setting3_title);
		setting4_title = (TextView) findViewById(R.id.setting4_title);
		setting3_summary = (TextView) findViewById(R.id.setting3_summary);
		setting4_summary = (TextView) findViewById(R.id.setting4_summary);
		setting3_title.setTypeface(MainActivity.Font);
		setting4_title.setTypeface(MainActivity.Font);
		setting3_summary.setTypeface(MainActivity.Font);
		setting4_summary.setTypeface(MainActivity.Font);
		go1 = (Button) findViewById(R.id.go1);
		go2 = (Button) findViewById(R.id.go2);
		go1.setTypeface(MainActivity.Font);
		go2.setTypeface(MainActivity.Font);
		
		// Slide Menu
		main = (Button) findViewById(R.id.mainscreen);
		update = (Button) findViewById(R.id.updatelog);
		spica = (Button) findViewById(R.id.spica);
		pure = (Button) findViewById(R.id.pure);
		save = (Button) findViewById(R.id.save);
		prev = (Button) findViewById(R.id.prev);
		miracle = (Button) findViewById(R.id.miracle);
		brand = (Button) findViewById(R.id.brand);
		spisave = (Button) findViewById(R.id.spisave);
		delete = (Button) findViewById(R.id.delete);
		promoting = (Button) findViewById(R.id.promoting);
		setting = (Button) findViewById(R.id.setting);
		developerinfo = (Button) findViewById(R.id.developerinfo);
		donate = (Button) findViewById(R.id.donate);

		// Slide Menu Fonts
		main.setTypeface(MainActivity.Font);
		update.setTypeface(MainActivity.Font);
		spica.setTypeface(MainActivity.Font);
		pure.setTypeface(MainActivity.Font);
		save.setTypeface(MainActivity.Font);
		prev.setTypeface(MainActivity.Font);
		miracle.setTypeface(MainActivity.Font);
		brand.setTypeface(MainActivity.Font);
		spisave.setTypeface(MainActivity.Font);
		delete.setTypeface(MainActivity.Font);
		promoting.setTypeface(MainActivity.Font);
		setting.setTypeface(MainActivity.Font);
		developerinfo.setTypeface(MainActivity.Font);
		donate.setTypeface(MainActivity.Font);
	
		go1.setOnClickListener(new View.OnClickListener() {

			@Override
			public void onClick(View v) {
				Uri uri = Uri.parse("mailto:sirospace@sirospace.com");
				Intent it = new Intent(Intent.ACTION_SENDTO, uri);
				startActivity(it);
			}
		});
		go2.setOnClickListener(new View.OnClickListener() {

			@Override
			public void onClick(View v) {
				licenseintent();
			}
		});
	}
	
	@Override
	public boolean onKeyDown(int keyCode, KeyEvent event) {
		if (keyCode == KeyEvent.KEYCODE_BACK) {

			View view = this.getLayoutInflater().inflate(R.layout.customdialog,
					null);
			TextView txtTitle = (TextView) view.findViewById(R.id.title);
			txtTitle.setText(R.string.quittitle);
			txtTitle.setTextColor(Color.WHITE);
			txtTitle.setTextSize(20);
			txtTitle.setTypeface(MainActivity.Font);
			TextView message = (TextView) view.findViewById(R.id.message);
			message.setText(R.string.quitmessage);
			message.setTextColor(Color.WHITE);
			message.setTypeface(MainActivity.Font);
			AlertDialog.Builder builer = new AlertDialog.Builder(this);
			builer.setView(view);
			builer.setPositiveButton(android.R.string.yes,
					new DialogInterface.OnClickListener() {
						@Override
						public void onClick(DialogInterface dialog, int which) {
							android.os.Process.killProcess(android.os.Process
									.myPid());
						}
					});
			builer.setNegativeButton(android.R.string.no, null).show();

			return true;
		}

		return super.onKeyDown(keyCode, event);
	}


	/**
	 * Send App data
	 */
	public void sendAppData(View v) throws NameNotFoundException {
		ArrayList<Map<String, String>> metaInfoArray = new ArrayList<Map<String, String>>();

		// If application is support Android platform.
		Map<String, String> metaInfoAndroid = new Hashtable<String, String>(1);
		metaInfoAndroid.put("os", "android");
		metaInfoAndroid.put("devicetype", "phone");
		metaInfoAndroid.put("installurl",
				"market://details?id=angeloid.dreamnarae");
		metaInfoAndroid.put("executeurl", "kakaoLinkTest://starActivity");

		// add to array
		metaInfoArray.add(metaInfoAndroid);

		// Recommended: Use application context for parameter.
		KakaoLink kakaoLink = KakaoLink.getLink(getApplicationContext());

		// check, intent is available.
		if (!kakaoLink.isAvailableIntent()) {
			alert(getString(R.string.ishavekatok));
			return;
		}

		/**
		 * @param activity
		 * @param url
		 * @param message
		 * @param appId
		 * @param appVer
		 * @param appName
		 * @param encoding
		 * @param metaInfoArray
		 */
		String app_name = getString(R.string.app_name);
		String message = getString(R.string.kakaotalkmessage);
		kakaoLink
				.openKakaoAppLink(
						this,
						"market://details?id=angeloid.dreamnarae",
						message,
						getPackageName(),
						getPackageManager().getPackageInfo(getPackageName(), 0).versionName,
						app_name, encoding, metaInfoArray);
	}

	private void alert(String message) {
		View view = this.getLayoutInflater().inflate(R.layout.customdialog,
				null);
		TextView txtTitle = (TextView) view.findViewById(R.id.title);
		txtTitle.setText(R.string.app_name);
		txtTitle.setTextColor(Color.WHITE);
		txtTitle.setTextSize(20);
		TextView message1 = (TextView) view.findViewById(R.id.message);
		message1.setText(message);
		message1.setTextColor(Color.WHITE);
		AlertDialog.Builder builder = new Builder(Settings.this);
		builder.setView(view);
		builder.setPositiveButton(android.R.string.ok, null).create().show();
	}

	public void licenseintent() {
		startActivity(new Intent(this, License.class));
	}

	public void mainscreen(View v) {
		startActivity(new Intent(this, MainActivity.class));
		finish();
	}

	public void updatelog(View v) {
		startActivity(new Intent(this, Update_Main.class));
		finish();
	}

	public void spicascreen(View v) {
		startActivity(new Intent(this, SPiCa.class));
		finish();
	}

	public void purescreen(View v) {
		startActivity(new Intent(this, Pure.class));
		finish();
	}

	public void savescreen(View v) {
		startActivity(new Intent(this, Save.class));
		finish();
	}

	public void prevscreen(View v) {
		startActivity(new Intent(this, Prev.class));
		finish();
	}

	public void miraclescreen(View v) {
		startActivity(new Intent(this, Miracle.class));
		finish();
	}

	public void brandscreen(View v) {
		startActivity(new Intent(this, Brand.class));
		finish();
	}

	public void spisavescreen(View v) {
		startActivity(new Intent(this, SPiSave.class));
		finish();
	}

	public void deletescreen(View v) {
		startActivity(new Intent(this, Delete.class));
		finish();
	}

	public void promotingscreen(View v) {
		try {
			sendAppData(v);
		} catch (NameNotFoundException e) {
			e.printStackTrace();
		}
	}

	public void settingscreen(View v) {
		// startActivity(new Intent(this, Settings.class));
	}

	public void developerinfoscreen(View v) {
		startActivity(new Intent(this, Developer_Info.class));
		finish();
	}

	public void donatescreen(View v) {
		startActivity(new Intent(this, Donate.class));
		finish();
	}
}