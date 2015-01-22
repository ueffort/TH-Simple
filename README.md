# TH-Simple
Two clusters of Hadoop: 简化在2个Hadoop上的统一操作
简化2个集群上的统一操作，提供以下工具方便操作

全局替换变量：这些参数主要用于替换pig脚本，用来兼容不同的平台
	STORAGE_PREFIX:HADOOP脚本执行后的存储路径，例如：亚马逊的s3:/
	PROJECT_PATH:项目目录，本地就是当前目录，集群就是通过upload上传的目录
	CLUSTER_TYPE:区分集群的类型，用在pig参数中，可用于不同集群加载不同的jar包，例如：-aws
	COMBINE_PATH:配合pig-tools中的combine参数，如果脚本需要combine则会设置该参数，例如：/tmp_{PROJECT_NAME}_{SCRIPT_NAME}/
				使用该参数，无需添加STORAGE_PREFIX
	
	(COMBINE_REMOTE|COMBINE_LOCAL):该参数会提交到combine脚本中，用作2份数据的存放目录
				
注：pig脚本最后的store路径一定要包含STORAGE_PREFIX和COMBINE_PATH参数中的一个，保证数据在脚本控制范围内

通过设定export ANSIBLE_VERBOSE=(-v,-vv,-vvv,-vvvv)即可打开详细信息用于调试，但对于脚本内可能会产生获取输出的错误

全局命令参数：
	--local:本地执行
	--remote:集群执行
	必须跟在一下3个工具的第一个参数
	对于默认的both模式，会将本机及集群的输出一同输出，并且会将执行返回值相加

将项目目录/bin加入到环境变量PATH中
	
1.cluster-tools:
	upload:将当前目录内的内容上传至集群中，（本地 远程） 支持tar命令参数，--exclude=data/ --exclude=logs/ --exclude=tmp/ 
	
	download:将集群中项目中的文件下载到当前目录下，（本地 远程）支持tar命令参数，--exclude=data/ --exclude=logs/ --exclude=tmp/ 
	
	shell:分别在2个集群上执行命令，参数是完整的命令行

2.pig-tools:替代pig执行命令
	--combine:如果设定，自动将{script}-combine.pig脚本作为执行完后的合并脚本，用于对local和remote分别执行script后的数据合并脚本，如果type为both则会执行，否则不执行
		合并逻辑：执行script后，将存放在CUMBINE_PATH内的数据下载到本地并且存放到本地集群，将2个数据通过combine脚本进行合并，并且最终存放在本地集群
		有一个集群执行错误，则不会发起合并操作
	其余参数不变
	script:执行的脚本

3.hadoop-tools:代替hadoop执行命令，将fs的命令单独出来
	dfs：因为云上的存储不是存放在当前集群，都是第三方服务形式，所以将dfs命令独立出来，提供有限的操作命令符
		-ls:一个参数，列出目录文件
		-rmr|-rm:一个参数，删除文件夹或文件
		-touchz：1个参数，创建一个空文件
		-put:2个参数，创建一个文件
		-get：2个参数，下载文件到本地
		-test:1个参数，判断文件是否存在
	如果想直接访问集群自身的文件系统，则可以使用命令fs


待开发：
1.支持2集群之间文件的转移
2.简化hadoop和pig用shell控制执行目录，可以将该变量写于ansible的全局变量，方便调用，简化shell的处理逻辑
