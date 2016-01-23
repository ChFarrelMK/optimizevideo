#!/usr/bin/python3

##########################################################################
#    optimize_mkv.py
#    Copyright (C) 2016  Andreas Wenzel (https://github.com/awenny)
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>.
##########################################################################

# This is basically a rewrite of optimize_mkv.sh as Python, but with
# enhancedment of using a configuration file (sqlite3) to watch on folders
# and maintain already processed files with statistics.
# It can be regularily started to automatically find new files in folders
# and optimize them.
#
# Main purpose:
# 1. Look for files with "mkv" extension in configured folders
# 2. Use ffmpeg to convert it into a more optimized codec (configurable)
# 3. All audio tracks are copied as they are
# 4. Only video track will be optimized
#
# CAUTION:
# If you are familiar with SQL and sqlite3, and want to change configuration
# in the repository database manually, be careful to enable foreign keys
# first. Otherwise you might get inconsistent data.
# Default in sqlite3 is usually with deactived foreign keys!!!
# But under no circumstance, change definition of existing tables!!!


# set current repository version to be able to migrate tables from
# older repositories
# Do not change this value unless you know what you're doing
current_repository_version = 1

# Define initial default values for process arguments
optimization_default_options = [
    ("-c:v libx265",),   # HEVC
    ("-crf 20",),        # high quality
    ("-c:a copy",),
    ("-map 0",)
]

# Define initial default values for application
application_options = {"target_extension": "mkv"}


import os
import sys
from datetime import date, datetime
import sqlite3
import argparse

parser = argparse.ArgumentParser(description='Reencode video files with '
                                 'certain options')
subparsers = parser.add_subparsers(help='sub-command help', dest='command')
parser_conf = subparsers.add_parser('config', aliases=['c', 'conf',
                                                       'configure'],
                                    help='Add or modify configuration')
parser_conf_group1 = parser_conf.add_mutually_exclusive_group()
parser_conf.add_argument('-c', '--current-folder', action='store_true',
                         help='Add current folder to watch list')
parser_conf.add_argument('-l', '--folder-list', metavar='folder',
                         action='store', nargs="+",
                         help='Provide folder list')
parser_conf_group1.add_argument('-f', '--add-folder', action='store_true',
                               help='Add folder(s) to watch list based on '
                               'provided options')
parser_conf_group1.add_argument('-F', '--delete-folder', action='store_true',
                               help='Delete folder(s) from watch list based '
                               'on provided options')
parser_conf.add_argument('-o', '--add-option-folder', metavar='option_folder',
                         action='store', nargs="+",
                         help='Add option(s) (with value(s)) to the provided '
                         'folder(s)')
parser_conf.add_argument('-O', '--delete-option-folder',
                         metavar='option_folder', action='store', nargs="+",
                         help='Delete option(s) (with value(s)) from the '
                         'provided folder(s)')
parser_conf.add_argument('-d', '--add-default-option',
                         metavar='default_option', action='store', nargs="+",
                         help='Add default option(s) (with value(s)) for all '
                         'executions')
parser_conf.add_argument('-D', '--delete-default-option',
                         metavar='default_option', action='store', nargs="+",
                         help='Delete default option(s) from all executions')
parser_conf.add_argument('-i', '--add-ignore-extension-folder',
                         metavar='ignore_extension', action='store', nargs="+",
                         help='Add extenstion(s) to ignore to all provided '
                         'folder(s)')
parser_conf.add_argument('-I', '--delete-ignore-extension-folder',
                         metavar='ignore_extension', action='store', nargs="+",
                         help='Delete extenstion(s) to ignore from all '
                         'provided folder(s)')
parser_conf.add_argument('-a', '--add-extension-as-done', metavar='extension',
                         action='store', nargs="+",
                         help='Add files found in folder(s) filtered by '
                         'extension(s) as processed')
parser_conf.add_argument('-p', '--add-file-as-done', metavar='videofile',
                         action='store', nargs="+",
                         help='Add files found in folder(s) filtered by '
                         'extension(s) as processed')
parser_exec = subparsers.add_parser('execute', aliases=['execute', 'exec', 'e',
                                                        'run', 'r'],
                                    help='Run optimization process')
parser_exec.add_argument('Video_files', metavar='videofile', nargs="*",
                         help='File name to optimize video')
parser_stat = subparsers.add_parser('statistics', aliases=['stats', 'stat',
                                                           's'],
                                    help='Show statistics and analyse '
                                    'repository')
args = parser.parse_args()


MyName = os.path.basename(__file__)
if MyName.endswith(".py"):
    MyName = MyName[:-3]

homepath = os.getenv('HOME')
databasename = os.path.join(homepath, "." + MyName + ".db")


def InitializeDatabase(databasename):
    """
    Repository database does not exist, add new one and create tables
    Also populate some tables with initial values
    """

    print("This is the first start of {} => "
          "Initializing database".format(MyName))
    print("Please read the documentation on github about changing "
          "configuration")
    print("")

    conn = sqlite3.connect(databasename)

    c = conn.cursor()
    c.execute("CREATE TABLE repository_version ("
              "version_number UNSIGNED INTEGER NOT NULL PRIMARY KEY) "
              "WITHOUT ROWID")
    c.execute("CREATE TRIGGER NMR_repository_version BEFORE INSERT "
              "ON repository_version WHEN (SELECT COUNT(*) "
              "FROM repository_version) >= 1 BEGIN "
              "SELECT RAISE(FAIL, 'Only one row allowed!'); END")
    c.execute("CREATE TABLE watch_folder ("
              "watch_folder_id UNSIGNED INTEGER NOT NULL PRIMARY KEY "
              "AUTOINCREMENT, "
              "watch_folder_name TEXT NOT NULL, "
              "recursive_yn UNSIGNED TINYINT NOT NULL DEFAULT 1 "
              "CHECK(recursive_yn in (0, 1))) WITHOUT ROWID")
    c.execute("CREATE TABLE real_folder ("
              "real_folder_id UNSIGNED INTEGER NOT NULL PRIMARY KEY "
              "AUTOINCREMENT, "
              "watch_folder_id UNSIGNED INTEGER NOT NULL REFERENCES "
              "watch_folder (watch_folder_id) ON DELETE CASCADE ON UPDATE CASCADE, "
              "real_folder_name TEXT NOT NULL "
              "UNIQUE(real_folder_name)) WITHOUT ROWID")
    c.execute("CREATE TABLE folder_ignore_extension ("
              "watch_folder_id UNSIGNED INTEGER NOT NULL REFERENCES "
              "watch_folder (watch_folder_id) ON DELETE CASCADE ON UPDATE CASCADE, "
              "ignore_extension TEXT NOT NULL, "
              "PRIMARY KEY (watch_folder_id, ignore_extension)) WITHOUT ROWID")
    c.execute("CREATE TABLE folder_optimize_file ("
              "real_folder_id UNSIGNED INTEGER NOT NULL REFERENCES "
              "watch_folder (watch_folder_id) ON DELETE CASCADE ON UPDATE CASCADE, "
              "file_name TEXT NOT NULL, original_extension TEXT NOT NULL, "
              "original_size UNSIGNED BIGINT NOT NULL, "
              "original_first_seen_at TEXT NOT NULL, optimize_pid INTEGER, "
              "optimization_started_at TEXT, optimized_extension TEXT, "
              "optimized_size UNSIGNED BIGINT, runtime_seconds INTEGER, "
              "file_status TINYINT NOT NULL, "
              "PRIMARY KEY (watch_folder_id, file_name)) WITHOUT ROWID")
    c.execute("CREATE TABLE folder_option ("
              "watch_folder_id UNSIGNED INTEGER NOT NULL REFERENCES "
              "watch_folder (watch_folder_id) ON DELETE CASCADE ON UPDATE CASCADE, "
              "folder_option TEXT NOT NULL, "
              "PRIMARY KEY (watch_folder_id, folder_option)) WITHOUT ROWID")
    c.execute("CREATE TABLE optimization_default_option ("
              "default_option TEXT PRIMARY KEY NOT NULL) WITHOUT ROWID")
    c.execute("CREATE TABLE current_running ("
              "started_at TEXT NOT NULL PRIMARY KEY, "
              "pid UNSIGNED INTEGER NOT NULL) WITHOUT ROWID")
    c.execute("CREATE TABLE message (message_text TEXT NOT NULL PRIMARY KEY) "
              "WITHOUT ROWID")
    c.execute("CREATE TRIGGER NMR_message BEFORE INSERT ON message "
              "WHEN (SELECT COUNT(*) FROM message) >= 1 BEGIN "
              "SELECT RAISE(FAIL, 'Only one row allowed!'); END")
    c.execute("CREATE TABLE application_option ("
              "option_key TEXT NOT NULL PRIMARY KEY, "
              "option_value TEXT NOT NULL) WITHOUT ROWID")
    c.execute("INSERT INTO repository_version (version_number) "
              "VALUES (?)", [current_repository_version, ])
    c.executemany("INSERT INTO optimization_default_option VALUES (?)",
                  optimization_default_options)
    for Option in optimization_default_options:
        print("Added default option \"{}\" to all executions"
              .format(Option[0]))
    for key, value in application_options.items():
        c.execute("INSERT INTO application_option VALUES (?, ?)", (key, value))
        print("Added application option \"{}\" = \"{}\"".format(key, value))
    conn.commit()
    conn.close()


def OpenReadDatabase(databasename):
    """
    Repository database exists. Read data into variables
    """
    conn = sqlite3.connect(databasename)
    c = conn.cursor()
    c.execute("PRAGMA FOREIGN_KEYS = ON")

    # We do have a trigger to prevent this situation on table
    # But to be sure!
    c.execute("SELECT COUNT(*) FROM repository_version")
    if c.fetchone()[0] != 1:
        print("Error! Table \"repository_version\" does not contain only one "
              "row as expected!")
        sys.exit(1)

    c.execute("SELECT version_number FROM repository_version")
    if c.fetchone()[0] < current_repository_version:
        # Database version is old, need to migrate to newest version
        pass

    return(conn, c)


def Configuration(databasename):
    """
    Manipulate configuration directly in database file.
    """

    conn = sqlite3.connect(databasename)
    c = conn.cursor()
    c.execute("PRAGMA FOREIGN_KEYS = ON")

    folderlist = []

    if args.folder_list:
        folderlist = args.folder_list
        if args.current_folder == True:
            folderlist.append(os.path.abspath(os.path.curdir))
    elif args.current_folder:
        folderlist.append(os.path.abspath(os.path.curdir))

    # Delete watch folder
    if folderlist and args.delete_folder == True:
        for thisFolder in folderlist:
            c.execute("SELECT COUNT(*) FROM watch_folder "
                      "WHERE watch_folder_name = ?", [thisFolder])
            if c.fetchone()[0] != 1:
                print("Folder \"{}\" is not not in watch list", [thisFolder])
            else:
                c.execute("DELETE FROM watch_folder WHERE watch_folder_name = ?",
                          [thisFolder])
                print("Deleted folder \"{}\" from watch list including all "
                      "related data".format(thisFolder))

    # Add folder(s) to watch list
    if folderlist and args.add_folder == True:
        for thisFolder in folderlist:
            c.execute("SELECT COUNT(*) FROM watch_folder "
                      "WHERE watch_folder_name = ?", [thisFolder])
            if c.fetchone()[0] > 0:
                print("Folder {} is already in watch list".format(thisFolder))
            else:
                # First, check tree if already a watch folder
                checkFolder, tail = os.path.split(thisFolder)
                while checkFolder:
                    c.execute("SELECT COUNT(*) FROM watch_folder "
                              "WHERE watch_folder_name = ?", [checkFolder])
                    if c.fetchone():
                        print("Folder \"{}\" is part of other folder already in "
                              "watch list")
                        checkFolder = False
                    else:
                        checkFolder, tail = os.path.split(checkFolder)

                if checkFolder:
                    # now, we need to end this iteration and do nothing
                    continue

                c.execute("INSERT INTO watch_folder (watch_folder_name) "
                          "VALUES (?)", [thisFolder])
                          currentRowId = c.lastrowid
                print("Added folder \"{}\" to watch list".format(thisFolder))
                # Always add extension "log" to new folder automatically
                c.execute("INSERT INTO folder_ignore_extension ("
                          "watch_folder_id, ignore_extension) VALUES (?, ?)",
                          [currentRowId, "log"])
                print("Added ignore extension \"{}\" to "
                      "folder \"{}\"".format("log", thisFolder))

    # Delete ignore extension(s) from watch folders
    if (folderlist and args.delete_ignore_extension_folder
            and args.delete_folder == False):
        for thisFolder in folderlist:
            for Ext in args.delete_ignore_extension_folder:
                c.execute("SELECT 1 FROM watch_folder AS a "
                          "JOIN folder_ignore_extension AS b "
                          "ON a.watch_folder_id = b.watch_folder_id "
                          "WHERE a.watch_folder_name = ? "
                          "AND b.ignore_extension = ? ", [thisFolder, Ext])
                if c.fetchone():
                    c.execute("DELETE FROM folder_ignore_extension "
                              "WHERE watch_folder_id = ("
                              "SELECT watch_folder_id "
                              "FROM watch_folder WHERE watch_folder_name = ?) "
                              "and ignore_extension = ?", [thisFolder, Ext])
                    print("Deleted ignore extension \"{}\" from "
                          "folder \"{}\"".format(Ext, thisFolder))
                else:
                    print("Ignore extension \"{}\" already exists for "
                          "folder \"{}\"".format(Ext, thisFolder))

    # Insert new extension(s) to ignore from watch folder
    if (folderlist and args.add_ignore_extension_folder
            and args.delete_folder == False):
        for thisFolder in folderlist:
            for Ext in args.add_ignore_extension_folder:
                c.execute("SELECT 1 FROM watch_folder AS a "
                          "JOIN folder_ignore_extension AS b "
                          "ON a.watch_folder_id = b.watch_folder_id "
                          "WHERE a.watch_folder_name = ? "
                          "AND b.ignore_extension = ? ", [thisFolder, Ext])
                if not c.fetchone():
                    c.execute("INSERT INTO folder_ignore_extension ("
                              "watch_folder_id, ignore_extension) "
                              "SELECT watch_folder_id, ? "
                              "FROM watch_folder "
                              "WHERE watch_folder_name = ?", [Ext, thisFolder])
                    print("Added ignore extension \"{}\" to "
                          "folder \"{}\"".format(Ext, thisFolder))
                else:
                    print("Ignore extension \"{}\" already exists for "
                          "folder \"{}\"".format(Ext, thisFolder))

    # Delete option(s) from watch folder
    if (folderlist and args.delete_option_folder
            and args.delete_folder == False):
        for thisFolder in folderlist:
            for Option in args.delete_option_folder:
                c.execute("SELECT 1 FROM watch_folder AS a "
                          "JOIN folder_option AS b "
                          "ON a.watch_folder_id = b.watch_folder_id "
                          "WHERE a.watch_folder_name = ? "
                          "AND b.folder_option = ? ", [thisFolder, Option])
                if c.fetchone():
                    c.execute("DELETE FROM folder_option "
                              "WHERE watch_folder_id = ("
                              "SELECT watch_folder_id "
                              "FROM watch_folder WHERE watch_folder_name = ?) "
                              "AND folder_option = ?", [thisFolder, Option])
                    print("Deleted option \"{}\" from "
                          "folder \"{}\"".format(Option, thisFolder))
                else:
                    print("Folder option \"{}\" does not exist for "
                          "folder \"{}\"".format(Option, thisFolder))

    # insert option(s) to watch folder
    if folderlist and args.add_option_folder and args.delete_folder == False:
        for thisFolder in folderlist:
            for Option in args.add_option_folder:
                c.execute("SELECT 1 FROM watch_folder AS a "
                          "JOIN folder_option AS b "
                          "ON a.watch_folder_id = b.watch_folder_id "
                          "WHERE a.watch_folder_name = ? "
                          "AND b.folder_option = ? ", [thisFolder, Option])
                if not c.fetchone():
                    c.execute("INSERT INTO folder_option (watch_folder_id, "
                              "folder_option) SELECT watch_folder_id, ? "
                              "FROM watch_folder "
                              "WHERE watch_folder_name = ?", [Option, thisFolder])
                    print("Added option \"{}\" to "
                          "folder \"{}\"".format(Option, thisFolder))
                else:
                    print("Folder option \"{}\" already exists for "
                          "folder \"{}\"".format(Option, thisFolder))

    # Find files and mark them based on extension as done
    if args.add_extension_as_done:
        foli = {}
        if folderlist:
            for row in c.execute("SELECT real_folder_id, real_folder_name, "
                                 "FROM real_folder"):
                if row[1] in folderlist:
                    foli[row[1]] = row[0]
        else:
            for row in c.execute("SELECT real_folder_id, real_folder_name, "
                                 "FROM real_folder"):
                foli[row[1]] = row[0]

        for thisFolder in foli.keys():
            for File in os.listdir(thisFolder):
                if (File.split(".")[-1] in args.add_extension_as_done
                        and not File.startswith(".")):
                    fileName = os.path.splitext(File)[0]
                    fileExt  = os.path.splitext(File)[1][1:]
                    fileSize = os.path.getsize(os.path.join(thisFolder, File))

                    c.execute("SELECT 1, file_status "
                              "FROM folder_optimize_file "
                              "WHERE real_folder_id = ? AND file_name = ? ",
                              [foli[thisFolder], fileName])
                    get = c.fetchone()
                    if not get:
                        c.execute("INSERT INTO folder_optimize_file ("
                                  "real_folder_id, file_name, "
                                  "original_extension, original_size, "
                                  "original_first_seen_at, optimize_pid, "
                                  "optimization_started_at, "
                                  "optimized_extension, optimized_size, "
                                  "runtime_seconds, file_status) "
                                  "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
                                             [foli[thisFolder], fileName,
                                                    fileExt, fileSize,
                                                    datetime.now(), -1,
                                                    datetime.now(), fileExt,
                                                    fileSize, -1, 1])
                        print("Added file \"{}\" to folder \"{}\" as done"
                              .format(File, thisFolder))
                    elif get[0] == 1 and get[1] == 0:
                        c.execute("UPDATE folder_optimize_file "
                                  "SET optimize_pid = ?,"
                                  "optimization_started_at = ?,"
                                  "optimized_extension = ?,"
                                  "optimized_size = ?, runtime_seconds = ?,"
                                  "file_status = ? "
                                  "WHERE real_folder_id = ? "
                                  "AND file_name = ?", [-1, datetime.now(),
                                                        fileExt, fileSize, -1,
                                                        1, foli[thisFolder],
                                                                fileName])
                        print("File \"{}\" in folder \"{}\" changed to "
                              "optimized".format(File, thisFolder))
                    else:
                        print("File \"{}\" in folder \"{}\" already optimized"
                              .format(File, thisFolder))


    conn.commit()
    conn.close()


def Execution():
    """
    Reading configuration database and process data in watch folders
    """
    pass


def GetWatchFolderId(folderName):
    """
    Search for foldername and return id of watch folder
    """
    c.execute("SELECT watch_folder_id FROM watch_folder "
              "WHERE watch_folder_name = ?",
              [folderName])

    return(c.fetchone[0])


def InsertNewRealFolder(watchFolderId, folderName):
    """
    Check if folder already exists and insert if not
    """
    c.execute("SELECT 1 FROM real_folder "
              "WHERE watch_folder_id = ? AND name = ?",
              [row[0], folderName])
    if not c.fetchone():
        c.execute("INSERT INTO real_folder ("
                  "watch_folder_id, real_folder_name) "
                  "VALUES (?, ?)",
                  [row[0], folderName])


def IdentifyNewRealFolders:
    """
    Based on watch folders generate list of real folders
    """
    for row in c.execute("SELECT watch_folder_id, watch_folder_name "
                         "FROM watch_folder"):
        for root, dirs, files in os.walk(row[1]):
            InsertNewRealFolder(row[0], root)


def IdentifyNewFiles(databasename):
    """
    Check in registered folders for new arrived files and add them to
    repository database.
    """

    conn = sqlite3.connect(databasename)
    c = conn.cursor()
    c.execute("PRAGMA FOREIGN_KEYS = ON")

    # First, check if new folders have been created below our watch folders
    IdentifyNewRealFolders

    for row in c.execute("SELECT real_folder_id, watch_folder_id, real_folder_name "
                         "FROM real_folder"):
        ignoreExtensions = []

        for row2 in c.execute("SELECT ignore_extension "
                              "FROM folder_ignore_extension "
                              "WHERE watch_folder_id = ?", [row[1], ]):
            ignoreExtensions.append(row2[0])

        for File in os.listdir(row[1]):
            if (os.path.splitext(File)[1][1:] not in ignoreExtensions
                    and not File.startswith(".")):
                c.execute("SELECT 1 FROM folder_optimize_file "
                          "WHERE real_folder_id = ? AND file_name = ?",
                          [row[0], os.path.splitext(File)[0]])
                if not c.fetchone():
                    fileSize = os.path.getsize(os.path.join(row[1], File))
                    try:
                        c.execute("INSERT INTO folder_optimize_file ("
                                  "real_folder_id, file_name, "
                                  "original_extension, "
                                  "original_first_seen_at, original_size, "
                                  "file_status) VALUES (?, ?, ?, ?, ?, ?)",
                                  [row[0], os.path.splitext(File)[0],
                                    datetime.now(),
                                    os.path.splitext(File)[1][1:],
                                    fileSize, 0])
                    except sqlite3.IntegrityError as e:
                        print("Ho, foreign key to real folder violated! "
                              "Deleted in the meantime?")
                    else:
                        print("Added file \"{}\" in folder \"{}\" to optimize "
                              "list".format(File, row[1]))

    conn.commit()
    conn.close()


if __name__ == '__main__':
    if not os.path.exists(databasename):
        InitializeDatabase(databasename)

    if args.command in ("execute", "exec", "e", "run", "r"):
        IdentifyNewFiles(databasename)
        Execution(databasename)
    elif args.command in ("configure", "config", "conf", "c"):
        Configuration(databasename)
        IdentifyNewFiles(databasename)
    elif args.command in ("statistics", "stats", "stat", "s"):
        IdentifyNewFiles(databasename)
