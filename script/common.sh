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
export TMP_COMBINE_PATH="/"${USER}"_"${PROJECT}"_"${TIMESTAMP}
export TMP_ANSIBLE_PATH=$ANSIBLE_PATH"/tmp/"`date +%Y-%m-%d`"/"${PROJECT}
mkdir -p $TMP_ANSIBLE_PATH

export REMOTE_MODE=remote
export LOCAL_MODE=local
export BOTH_MODE=both
export ANSIBLE_OUT=

cluster_host=$BOTH_MODE
for p in $*
do
	case $p in 
		--local)
			cluster_host=$LOCAL_MODE;
			shift
		;;
		--remote)
			cluster_host=$REMOTE_MODE;
			shift
		;;
	esac
done
export CLUSTER_HOST=$cluster_host


function ansible_play(){
	cd $ANSIBLE_PATH;
	playbook=$1
	vars=$2
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
	shell="ansible-playbook "$ANSIBLE_VERBOSE" "$playbook".yml --extra-vars \""$vars" RETURN_LOG="$md5"\" --tags \""$tags"\""
	if [ $back ]
	then
		shell=$shell" &"
	fi
	if [ -z $ANSIBLE_VERBOSE ]
	then
		#echo out$shell
		out=`eval $shell`
	else
		echo $shell
		eval $shell
	fi
	cd $CURRENT_PATH;
	ANSIBLE_OUT=$md5
}

function parse_ansible_return(){
	f=$1
	s=`ls ${f}_* 2>/dev/null`
	if [ $? -eq 0 ]
	then
		l=${#f}
		l=$[$l + 1]
		c=`ls ${f}_* | head -n 1`
		cat $c
		rm -f $c
		rm -f $f
		e=${c:$l:3}
	else
		echo "Ansible error: Out File loss! file:"$f
		rm -rf $f
		e=1
	fi
	return $e
}

function replace_globals(){
	param=$1;
	mode=$2;
	#不用存储在永久存储中，直接存储在集群的hdfs即可
	COMBINE_LOCAL=${LOCAL_HADOOP_TMP}"/"${TMP_COMBINE_PATH}_${LOCAL_MODE}
	COMBINE_REMOTE=${REMOTE_HADOOP_TMP}"/"${TMP_COMBINE_PATH}_${REMOTE_MODE}
	if [ $mode = $REMOTE_MODE ]
	then
		CLUSTER_TYPE="-"$REMOTE_TYPE
		PROJECT_PATH=$REMOTE_PATH
		STORAGE_PREFIX=$REMOTE_STORAGE_PREFIX
		COMBINE_PATH=$COMBINE_REMOTE
	elif [ $mode = $LOCAL_MODE ]
	then
		CLUSTER_TYPE=
		PROJECT_PATH=$LOCAL_PATH
		STORAGE_PREFIX=
		COMBINE_PATH=$COMBINE_LOCAL
	fi
	awk_shell="echo '"$param"' | awk 'BEGIN{"
	t=0
	for i in CLUSTER_TYPE PROJECT_PATH STORAGE_PREFIX COMBINE_PATH COMBINE_LOCAL COMBINE_REMOTE
	do
		t=$[$t + 1]
		awk_shell=${awk_shell}"a[$t]=\"{"$i"}\";"
	done
	t=0
	for i in "$CLUSTER_TYPE" "$PROJECT_PATH" "$STORAGE_PREFIX" "$COMBINE_PATH" "$COMBINE_LOCAL" "$COMBINE_REMOTE"
	do
		t=$[$t + 1]
		awk_shell=${awk_shell}"b[$t]=\""$i"\";"
	done
	awk_shell=${awk_shell}'}{ori=$0;for(i in a){gsub(a[i],b[i],ori);}print ori}'"'"
	#echo "$awk_shell"
	param=`eval $awk_shell`
	echo $param
}
