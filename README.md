# Auto Backuper

Auto Backuper is a **BASH** script which can be used to backup PostgreSQL databases and given files/folders.

It's written in BASH scripting language and only needs **cURL**.


## Features

* Simple configuration, all configurations in one place: backup.info
* Sets up daily and weekly CRON jobs
* Uploads backup files directly to Dropbox
* Cleans up after itself, deletes older files


## Getting started

First, clone the repository using git (recommended):

```bash
git clone https://github.com/msadig/docker-autobackuper
```

or download the script manually using this command:

```bash
curl "https://raw.githubusercontent.com/msadig/docker-autobackuper/master/backuper.sh" -o backuper.sh
```

To configure:

```bash
 $ bash ./backuper.sh setup
 $ nano ./backup.conf
```

The first time you run `./backuper.sh setup`, you'll be guided through a wizard in order to configure access to your Dropbox. For more info visit - https://github.com/andreafabrizi/Dropbox-Uploader


## Usage

The syntax is quite simple:

```
bash ./backuper.sh COMMAND
```

**Available commands:**

* **setup**  
Sets up script  


* **daily**  
To backup only today's files and directories and upload to Dropbox.


* **weekly**  
To backup all files and directories and upload to Dropbox.


* **cronit**  
To set up CRON jobs



**Examples:**
```bash
    bash ./backuper.sh setup
    bash ./backuper.sh daily
    bash ./backuper.sh weekly
```


## Tested Environments

* GNU Linux
* MacOSX


## Credits

 * https://github.com/msadig/Dropbox-Uploader
 * http://www.defitek.com/blog/2010/01/06/a-simple-yet-effective-postgresql-backup-script/#codesyntax_1
 * https://www.odoo.com/forum/help-1/question/how-to-setup-a-regular-postgresql-database-backup-4728
 * https://gist.github.com/matthewlehner/3091458
 * https://stackoverflow.com/a/29913462/968751 - Dump PostgreSQL docker container
