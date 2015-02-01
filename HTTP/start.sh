for i in *.ru
do echo $i
	head -1 $i
	rackup -D $i
done
