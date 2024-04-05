#!/bin/python

import sys
import urllib.request
import xml.etree.ElementTree as xml_parser

guava_metadata_url = "https://repo1.maven.org/maven2/com/google/guava/guava/maven-metadata.xml"
androidx_package_table_url = "https://developer.android.com/jetpack/androidx/versions"
androidx_package_info_url = "https://developer.android.com/jetpack/androidx/releases/"

lifecycle_subpkg_list = [
    "androidx.lifecycle:lifecycle-common-java8",
    "androidx.lifecycle:lifecycle-common",
    "androidx.lifecycle:lifecycle-livedata-core",
    "androidx.lifecycle:lifecycle-livedata",
    "androidx.lifecycle:lifecycle-process",
    "androidx.lifecycle:lifecycle-reactivestreams",
    "androidx.lifecycle:lifecycle-runtime",
    "androidx.lifecycle:lifecycle-service",
    "androidx.lifecycle:lifecycle-viewmodel-savedstate",
    "androidx.lifecycle:lifecycle-viewmodel"
]

androidx_required_packages_map = {
    "activity": ["activity"],
    "annotation": ["annotation"],
    "appcompat": ["appcompat", "androidx.appcompat:appcompat-resources"],
    "arch.core": ["androidx.arch.core:core-common", "androidx.arch.core:core-runtime"],
    "asynclayoutinflater": ["asynclayoutinflater"],
    "collection": ["collection"],
    "concurrent": ["androidx.concurrent:concurrent-futures"],
    "constraintlayout": [],
    "contentpager": ["contentpager"],
    "core": [],
    "cursoradapter": ["cursoradapter"],
    "customview": ["customview"],
    "drawerlayout": ["drawerlayout"],
    "dynamicanimation": ["dynamicanimation"],
    "fragment": ["fragment"],
    "gridlayout": ["gridlayout"],
    "heifwriter": ["heifwriter"],
    "interpolator": ["interpolator"],
    "lifecycle": lifecycle_subpkg_list,
    "loader": ["loader"],
    "palette": ["palette"],
    "remotecallback": ["remotecallback"],
    "savedstate": ["androidx.savedstate:savedstate"],
    "startup": ["androidx.startup:startup-runtime"],
    "textclassifier": ["textclassifier"],
    "transition": ["transition"],
    "vectordrawable": ["vectordrawable", "androidx.vectordrawable:vectordrawable-animated"],
    "versionedparcelable": ["versionedparcelable"],
    "viewpager": ["viewpager"]
}

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

def find_xml_node(content, index_path):
    node = xml_parser.fromstring(content)
    for index in index_path:
        node = node[index]
    return node.text

def extract_package_list(releases_html):
    table_start = releases_html.find("<table") + 1
    table_end = releases_html.find("</table", table_start)
    table = releases_html[table_start : table_end]

    n_columns = 0
    pos = 0
    while True:
        pos = table.find("<th", pos)
        if pos < 0:
            break
        pos += 4
        n_columns += 1

    pos = 0
    values = []
    while True:
        pos = table.find("<td>", pos)
        if pos < 0:
            break
        pos += 4
        next_tag = table.find(">", pos)
        if table[next_tag - 2 : next_tag] == "td":
            end_value = table.find("<", pos)
            if end_value - pos < 2:
                values.append("")
            else:
                values.append(table[pos : end_value])
            continue
        values.append(table[next_tag + 1 : table.find("<", next_tag)])
        pos = next_tag

    return values, n_columns

def build_package_version_map(table_values, n_columns, required_packages_map):
    package_version_list = {}

    idx = 0
    while idx < len(table_values):
        name = table_values[idx].split(" ")[0]
        if not required_packages_map or (name in required_packages_map and required_packages_map[name]):
            c = n_columns - 4
            version = table_values[idx+c]
            while not version and c < n_columns - 1:
                c += 1
                version = table_values[idx+c]
            if version:
                package_version_list[name] = version
        idx += n_columns

    #print(package_version_list)
    return package_version_list

def main(args):
    if len(args) < 2:
        print("Usage: ./androidx-package-list <output txt file>")
        print("e.g.   ./androidx-package-list pkg-androidx.txt")
        return

    guava_xml = download(guava_metadata_url)
    guava_url = ""
    if guava_xml:
        try:
            guava_version = find_xml_node(guava_xml, [2, 1]).replace("jre", "android")
            print(guava_version)
            guava_url = guava_metadata_url[0 : guava_metadata_url.rindex("/")]
            guava_url += "/" + guava_version + "/guava-" + guava_version + ".jar"
            print("Found guava package: " + guava_url)
        except Exception as ex:
            print("Guava package link not found, continuing (" + str(ex) + ")")

    releases_html = download(androidx_package_table_url)
    if not releases_html:
        print("Error: failed to get " + androidx_package_table_url)
        return

    main_package_table, main_columns = extract_package_list(releases_html)
    package_version_map = build_package_version_map(main_package_table, main_columns, androidx_required_packages_map)

    desired_list = sorted(androidx_required_packages_map)
    for pkg in desired_list:
        if not androidx_required_packages_map[pkg]:
            print("Retrieving package info for " + pkg + "...")
            html = download(androidx_package_info_url + pkg)
            table, n_columns = extract_package_list(html)
            sub_pkg_map = build_package_version_map(table, n_columns, None)
            sub_list = sorted(sub_pkg_map)
            for s in sub_list:
                name = "androidx." + pkg + ":" + s
                androidx_required_packages_map[pkg].append(name)
                package_version_map[name] = sub_pkg_map[s]
            
            print(sub_pkg_map)

    out_str = "" if not guava_url else (guava_url + "\n")
    for pkg in desired_list:
        subpkgs = androidx_required_packages_map[pkg]
        version = package_version_map[pkg] if pkg in package_version_map else ""
        for s in subpkgs:
            n_parts = len(s.split(":"))
            out_str += s
            out_str += ":" if n_parts > 1 else " "
            out_str += version if version else package_version_map[s]
            out_str += "\n"

    with open(args[1], "w") as f:
        f.write(out_str)

main(sys.argv)

