#!/usr/bin/env bash

# Any subsequent(*) commands which fail will cause the shell script to exit immediately
set -e

#Default values
CURRENT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_DATE=$(date '+%d-%b-%Y')
PREFIX=$(hostname)
GIT_RAW_REF="https://raw.githubusercontent.com/msadig/docker-autobackuper/master"
ERROR_STATUS=0
VERSION="0.1"
POSTGRES_USER=postgres

# Get config
if [ ! -f $CURRENT_PATH/backup.conf ]; then
  curl "${GIT_RAW_REF}/backup.conf" -o backup.conf
else
  . $CURRENT_PATH/backup.conf
fi


# ------------------------
# Backup database
database_backup() {
  # backup database
  mkdir -p ${TMP_DIR}/db
  docker exec -t $DB_CONTAINER pg_dumpall -c -U ${POSTGRES_USER} > ${TMP_DIR}/db/dump_${BACKUP_DATE}.sql
}

# Delete older backups of database
database_clean() {
  rm -f ${TMP_DIR}/db/dump_${BACKUP_DATE}.sql
}


# ------------------------
# Usage
function usage
{
  echo -e "Auto Backuper v$VERSION"
  echo -e "Sadig Muradov - sadig@muradov.org\n"
  echo -e "Usage: $0 COMMAND"
  echo -e "\nCommands:"

  echo -e "\t setup		For setting up the script's configuration"
  echo -e "\t cronit		To set up CRON jobs"
  echo -e "\t daily		To backup only today's files and directories and upload to Dropbox"
  echo -e "\t weekly		To backup all files and directories and upload to Dropbox"


  echo -en "\nPlease see the README file for more info.\n\n"
  exit 1
}


# ------------------------
# Setup Dropbox uploader
function setup_dropbox {
  # Setting up the Dropbox API
  # - https://github.com/andreafabrizi/Dropbox-Uploader | https://www.andreafabrizi.it/?dropbox_uploader
  if [ ! -f ./dropbox_uploader.sh ]; then
    curl "https://raw.githubusercontent.com/andreafabrizi/Dropbox-Uploader/master/dropbox_uploader.sh" -o dropbox_uploader.sh
  fi
  chmod +x dropbox_uploader.sh # make executable
  ./dropbox_uploader.sh # setup Dropbox
  chmod +r $HOME/.dropbox_uploader
}

# Setup the CRONs
function setup_crons {
  # - http://stackoverflow.com/a/8106460/968751
  me="$(basename "$(test -L "$0" && readlink "$0" || echo "$0")")"

  # files
  daily_command="/bin/bash $CURRENT_PATH/${me} daily"
  daily_job="0 5 * * * $daily_command >/dev/null 2>&1" # The backup runs job daily at 5am.
  cat <(fgrep -i -v "$daily_command" <(crontab -l)) <(echo "$daily_job") | crontab -

  weekly_command="/bin/bash $CURRENT_PATH/${me} weekly"
  weekly_job="0 5 * * 1 $weekly_command >/dev/null 2>&1" # Run the backup at 5am on the first of every monday.
  cat <(fgrep -i -v "$weekly_command" <(crontab -l)) <(echo "$weekly_job") | crontab -
}

# General setup
setup() {
  echo -e "\nDROPBOX_CONF="$HOME"/.dropbox_uploader" >> $CURRENT_PATH/backup.conf
  . $CURRENT_PATH/backup.conf

  # If wants create Cron jobs to backup
  read -p "Do you wish to create CRON jobs? [y/N]: " cron_it
  if [ "$cron_it" == "y" ] ; then
    setup_crons
  fi


  # Dropbox
  setup_dropbox
}

# ------------------------
# Backup files and folders

# Daily backups
bkp_daily() {
  database_backup

  if [ "$ARCHIVED" = "Y" ]; then

    BACKUP_FILE=$TMP_DIR/bkp_daily_${PREFIX}_$BACKUP_DATE.tar.gz

    # Backup of the today created files
    # - http://stackoverflow.com/a/12305562/968751
    find $BKP_DIRS -type f -prune -mtime -1 -print0 | tar -czf $BACKUP_FILE --null -T -

    # Upload to Dropbox
    $CURRENT_PATH/dropbox_uploader.sh -qf $DROPBOX_CONF upload $BACKUP_FILE $DROPBOX_DIR

    # clear temp file
    rm -rf $BACKUP_FILE
  else
    find $BKP_DIRS -type f -prune -mtime -1 | xargs -I {} $CURRENT_PATH/dropbox_uploader.sh -qsf $DROPBOX_CONF upload "{}" ${DROPBOX_DIR}$(basename "{}")
    # find $BKP_DIRS -type f -prune -mtime -1 | xargs -I {} echo $(dirname "{}")
  fi
  bkp_cleanup "day"
}

# Weekly backups
bkp_weekly() {
  database_backup

  if [ "$ARCHIVED" = "Y" ]; then

    BACKUP_FILE=$TMP_DIR/bkp_${PREFIX}_$BACKUP_DATE.tar.gz

    # compress files
    tar -czf $BACKUP_FILE $BKP_DIRS

    # Upload to Dropbox
    $CURRENT_PATH/dropbox_uploader.sh -qf $DROPBOX_CONF upload $BACKUP_FILE $DROPBOX_DIR

    rm -rf $BACKUP_FILE
  else
    # Upload to Dropbox
    for DIR in $BKP_DIRS
    do
      NEWDIR=$(cd $DIR/..; pwd)
      $CURRENT_PATH/dropbox_uploader.sh -qsf $DROPBOX_CONF upload $DIR ${DROPBOX_DIR}${NEWDIR}/
    done
  fi
  bkp_cleanup "week"
}

# Clean up older backup files
bkp_cleanup() {

  if [ "$1" = "day" ]; then

    DELDATE=`date --date="-$NUBMER_OF_DAYS day" +%d-%b-%Y`
    # echo $DELDATE
    $CURRENT_PATH/dropbox_uploader.sh -f $DROPBOX_CONF list $DROPBOX_DIR | grep $DELDATE'.tar.gz$' | grep 'daily' | awk '{print $3}' | xargs -I {} $CURRENT_PATH/dropbox_uploader.sh -qf $DROPBOX_CONF delete $DROPBOX_DIR"{}"

  elif [ "$1" = "week" ]; then

    DELDATE=`date --date="-$(( 7 * ${NUBMER_OF_DAYS} )) day" +%d-%b-%Y`
    # echo $DELDATE
    $CURRENT_PATH/dropbox_uploader.sh -f $DROPBOX_CONF list $DROPBOX_DIR | grep $DELDATE'.tar.gz$' | grep -v 'daily' | awk '{print $3}' | xargs -I {} $CURRENT_PATH/dropbox_uploader.sh -qf $DROPBOX_CONF delete $DROPBOX_DIR"{}"

  else
    echo "No date option set"
    ERROR_STATUS=1
  fi

  database_clean
}


################
#### START  ####
################

COMMAND=${@:$OPTIND:1}

#CHECKING PARAMS VALUES
case $COMMAND in
  setup)

    setup

    ;;

  cronit)

    setup_crons

    ;;

  database)

    database_backup
    database_clean

    ;;

  daily)

    bkp_daily

    ;;

  weekly)

    bkp_weekly

    ;;


  *)

    if [[ $COMMAND != "" ]]; then
      echo "Error: Unknown command: $COMMAND"
      ERROR_STATUS=1
    fi
    usage

    ;;
esac

exit $ERROR_STATUS

# CREDITS:
# - http://www.defitek.com/blog/2010/01/06/a-simple-yet-effective-postgresql-backup-script/#codesyntax_1
# - https://www.odoo.com/forum/help-1/question/how-to-setup-a-regular-postgresql-database-backup-4728
# - https://gist.github.com/matthewlehner/3091458
# - https://github.com/andreafabrizi/Dropbox-Uploader | https://www.andreafabrizi.it/?dropbox_uploader
$CURRENT_PATH/dropbox_uploader.sh -qsf $DROPBOX_CONF upload $DIR ${DROPBOX_DIR}${NEWDIR}/
        done
	fi
	bkp_cleanup "week"
}

# Clean up older backup files
bkp_cleanup() {
	if [ "$1" = "day" ]; then

		DELDATE=`date --date="-$NUBMER_OF_DAYS day" +%d-%b-%Y`
		# echo $DELDATE
		$CURRENT_PATH/dropbox_uploader.sh -f $DROPBOX_CONF list $DROPBOX_DIR | grep $DELDATE'.tar.gz$' | grep 'daily' | awk '{print $3}' | xargs -I {} $CURRENT_PATH/dropbox_uploader.sh -qf $DROPBOX_CONF delete $DROPBOX_DIR"{}"

	elif [ "$1" = "week" ]; then

		DELDATE=`date --date="-$(( 7 * ${NUBMER_OF_DAYS} )) day" +%d-%b-%Y`
		# echo $DELDATE
		$CURRENT_PATH/dropbox_uploader.sh -f $DROPBOX_CONF list $DROPBOX_DIR | grep $DELDATE'.tar.gz$' | grep -v 'daily' | awk '{print $3}' | xargs -I {} $CURRENT_PATH/dropbox_uploader.sh -qf $DROPBOX_CONF delete $DROPBOX_DIR"{}"

	else
		echo "No date option set"
		ERROR_STATUS=1
	fi
}


################
#### START  ####
################

COMMAND=${@:$OPTIND:1}

#CHECKING PARAMS VALUES
case $COMMAND in
	setup)

		setup

	;;

	cronit)

        setup_crons

    ;;


	daily)

        bkp_daily

    ;;

	weekly)

        bkp_weekly

    ;;


    *)

        if [[ $COMMAND != "" ]]; then
            echo "Error: Unknown command: $COMMAND"
            ERROR_STATUS=1
        fi
        usage

    ;;
esac

exit $ERROR_STATUS

# CREDITS:
# - http://www.defitek.com/blog/2010/01/06/a-simple-yet-effective-postgresql-backup-script/#codesyntax_1
# - https://www.odoo.com/forum/help-1/question/how-to-setup-a-regular-postgresql-database-backup-4728
# - https://gist.github.com/matthewlehner/3091458
# - https://github.com/andreafabrizi/Dropbox-Uploader | https://www.andreafabrizi.it/?dropbox_uploader
