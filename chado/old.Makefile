#convert postgres to mysql create table files

all :: cdbi

mysql :: \
		./modules/audit/audit.mysql \
		./modules/companalysis/companalysis.mysql \
		./modules/cv/cv.mysql \
		./modules/expression/expression.mysql \
		./modules/expression/rad.mysql \
		./modules/general/general.mysql \
		./modules/genetic/genetic.mysql \
		./modules/map/map.mysql \
		./modules/organism/organism.mysql \
		./modules/pub/pub.mysql \
		./modules/sequence/sequence.mysql \
		./modules/www/www.mysql \

graphviz :: \
		./modules/audit/audit.graphviz.png \
		./modules/companalysis/companalysis.graphviz.png \
		./modules/cv/cv.graphviz.png \
		./modules/expression/expression.graphviz.png \
		./modules/expression/rad.graphviz.png \
		./modules/general/general.graphviz.png \
		./modules/genetic/genetic.graphviz.png \
		./modules/map/map.graphviz.png \
		./modules/organism/organism.graphviz.png \
		./modules/pub/pub.graphviz.png \
		./modules/sequence/sequence.graphviz.png \
		./modules/www/www.graphviz.png

diagram :: \
		./modules/audit/audit.diagram.png \
		./modules/companalysis/companalysis.diagram.png \
		./modules/cv/cv.diagram.png \
		./modules/expression/expression.diagram.png \
		./modules/expression/rad.diagram.png \
		./modules/general/general.diagram.png \
		./modules/genetic/genetic.diagram.png \
		./modules/map/map.diagram.png \
		./modules/organism/organism.diagram.png \
		./modules/pub/pub.diagram.png \
		./modules/sequence/sequence.diagram.png \
		./modules/www/www.diagram.png

%.mysql: %.sql
	./bin/pg2my.pl $< > $@

%.graphviz.png: %.sql
	./bin/pg2graphviz.pl $< > $@

%.diagram.png: %.sql
	./bin/pg2diagram.pl $< > $@

cdbi:
	./bin/pg2cdbi.pl ./modules/*/*.sql > ./src/pgsql/Chado/AutoDBI.pm
	./bin/my2cdbi.pl ./modules/*/*.mysql > ./src/mysql/Chado/AutoDBI.pm

metadata: ./bin/ddltrans
	cat `find . -name \*.sql -print` > ./dat/chado.ddl
	./bin/ddltrans -s chado -f dtd ./dat/chado.ddl > ./dat/chado.dtd
	./bin/ddltrans -f html ./dat/chado.ddl > ./dat/chado.html
	./bin/ddltrans -f perl ./dat/chado.ddl > ./dat/chado.pl
	./bin/ddltrans -f xml ./dat/chado.ddl > ./dat/chado.xml


