#!/bin/python

import urllib.request
import xml.etree.ElementTree as xml_parser

repo_url = "https://dl.google.com/android/repository/repository2-1.xml"
html_title = "Android SDK Packages"

def download(url):
	response = ""
	retries = 10
	while not response:
		try:
			with urllib.request.urlopen(url) as f:
				if f.status != 200:
					continue
				response = str(f.read(), "utf8")
			break
		except:
			if retries > 0:
				time.sleep(0.5)
				retries -= 1
			else:
				return None

	return response

def extract_file_list(repo_xml):
	root = xml_parser.fromstring(repo_xml)
	filenames = []

	for pack in root.findall("remotePackage"):
		archives = pack.find("archives")
		if archives is None:
			continue

		for a in archives.findall("archive"):
			url = a.find("complete/url")
			if url is None:
				continue

			fname = url.text
			first_dot = fname.find(".")
			if first_dot < 0:
				continue

			if first_dot > 32:
				starts_with_hash = True
				for i in range(first_dot):
					c = ord(fname[i])
					if (c < 0x30 or c > 0x39) and (c < 0x41 or c > 0x46) and (c < 0x61 or c > 0x66):
						starts_with_hash = False
						break
				if starts_with_hash:
					fname = fname[first_dot+1:]

			filenames.append(fname)

	return filenames

def main():
	repo_xml = download(repo_url)
	if not repo_xml:
		print("Failed to get " + repo_url)
		return

	sdk_filenames = extract_file_list(repo_xml)

	html = """<!DOCTYPE html>
	<html>
		<head>
			<meta charset="UTF-8">
			<title>{0}</title>
		</head>
		<body>
			<h1>{0}</h1>
			<ul>\n""".format(html_title)

	for fname in sdk_filenames:
		html += "<li><a href=\"https://dl.google.com/android/repository/" + fname + "\">" + fname + "</a></li>\n"

	html += "</ul>\n</body>\n</html>"
	with open("sdk-package-list.html", "w") as f:
		f.write(html)

main()

