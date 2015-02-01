for i in *.pid
do echo "$i stopping"
	kill `cat $i`
done
