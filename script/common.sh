#!/bin/bash
# 根据当前登录帐号调整项目目录

CURRENT_PATH=$(pwd);
ROOT_PATH=$(cd `dirname $0`/../; pwd);
cd $CURRENT_PATH;

export USER=$USER
export PROJECT=`basename $(pwd)`;
. $ROOT_PATH/config;

export REMOTE_PATH=$REMOTE_PATH/$USER/$PROJECT;
export LOCAL_PATH=$CURRENT_PATH;
export TIMESTAMP=`date +%s`
daily_tmp_path=$ANSIBLE_PATH"/tmp/"`date +%Y-%m-%d`

mkdir -p $daily_tmp_path
chmod -f 777 $daily_tmp_path

export TMP_ANSIBLE_PATH=$daily_tmp_path"/"${USER}_${PROJECT}
mkdir -p $TMP_ANSIBLE_PATH
chmod -R 777 $TMP_ANSIBLE_PATH

export REMOTE_MODE=remote
export LOCAL_MODE=local
export BOTH_MODE=both
export ANSIBLE_OUT=

cluster_host=$BOTH_MODE
for p in $*
do
	case $p in 
		--local|--LOCAL)
			cluster_host=$LOCAL_MODE;
			shift
		;;
		--remote|--REMOTE)
			cluster_host=$REMOTE_MODE;
			shift
		;;
	esac
done
export CLUSTER_HOST=$cluster_host


function ansible_play(){
	playbook=$1
	vars=`echo "$2" | sed 's/"/\\\\"/g'`
	tags=$3
	back=$4
	timestamp=`date +%s`
	md5=$TMP_ANSIBLE_PATH"/"`echo $* $timestamp | md5sum | awk '{print $1}'`
	i=0
	while [ -f $md5 ]
	do
		i=$[$i + 1]
		md5=$TMP_ANSIBLE_PATH"/"`echo $* $i | md5sum | awk '{print $1}'`
	done
	touch $md5
	cd $ANSIBLE_PATH
	wait
	if [ -z $ANSIBLE_VERBOSE ]
	then
		ansible-playbook $ANSIBLE_VERBOSE $playbook.yml --extra-vars "$vars RETURN_LOG=$md5" --tags "$tags" 1>/dev/null 2>&1 &
	else
		echo ansible-playbook "$ANSIBLE_VERBOSE" "$playbook".yml --extra-vars "$vars RETURN_LOG=$md5" --tags "$tags"
		ansible-playbook $ANSIBLE_VERBOSE $playbook.yml --extra-vars "$vars RETURN_LOG=$md5" --tags "$tags" &
	fi
	if [ -z $back ]
	then
		wait
	fi
	cd $CURRENT_PATH;
	export ANSIBLE_OUT=$md5
}

function parse_ansible_return(){
	return_f=$1
	return_s=`ls ${return_f}_* 2>/dev/null`
	if [ $? -eq 0 ]
	then
		return_l=${#return_f}
		return_l=$[$return_l + 1]
		return_c=`ls ${return_f}_* | head -n 1`
		cat $return_c
		return_e=${return_c:$return_l:3}
		rm -f $return_c
		rm -f $return_f
	else
		echo "Ansible error: Out File loss! file:"$return_f
		rm -rf $return_f"*"
		return_e=1
	fi
	return $return_e
}

#  包含引号需要加转义符
function replace_globals(){
	filter=`echo "$1" | sed 's/"/\\\\"/g'`
	mode=$2;
	if [ $mode = $REMOTE_MODE ]
	then
		CLUSTER_TYPE="-"$REMOTE_TYPE
		PROJECT_PATH=$REMOTE_PATH
		STORAGE_PREFIX=$REMOTE_STORAGE_PREFIX
	elif [ $mode = $LOCAL_MODE ]
	then
		CLUSTER_TYPE=
		PROJECT_PATH=$LOCAL_PATH
		STORAGE_PREFIX=
	fi
	awk_shell="echo \""$filter"\" | awk 'BEGIN{"
	t=0
	for i in CLUSTER_TYPE PROJECT_PATH STORAGE_PREFIX
	do
		t=$[$t + 1]
		awk_shell=${awk_shell}"a[$t]=\"{"$i"}\";"
	done
	t=0
	for i in "$CLUSTER_TYPE" "$PROJECT_PATH" "$STORAGE_PREFIX"
	do
		t=$[$t + 1]
		awk_shell=${awk_shell}"b[$t]=\""$i"\";"
	done
	awk_shell=${awk_shell}'}{ori=$0;for(i in a){gsub(a[i],b[i],ori);}print ori}'"'"
	#echo "$awk_shell"
	filter=`eval "$awk_shell"`
	echo $filter
}
