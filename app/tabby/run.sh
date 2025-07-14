if [ $1 = 'build' ]
then
	echo "start to run tabby"
  java -Xmx32g -jar tabby.jar
elif [ $1 = 'load' ]
then
	java -jar tabby-vul-finder.jar load $2
elif [ $1 = 'query' ]
then
	java -jar tabby-vul-finder.jar query $2
elif [ $1 = 'pack' ]
then
  tar -czvf output.tar.gz ./output/*.csv
fi
