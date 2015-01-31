for i in routes*.pid
do echo "$i stopping"
	kill `cat $i`
done
