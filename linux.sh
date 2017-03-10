TGZ=/tmp/mqtt.tgz
RPO=mqtt
tar czvf $TGZ Tests Package.swift Sources
scp $TGZ nut:/tmp
ssh nut "cd /tmp;rm -rf $RPO;mkdir $RPO; cd $RPO; tar xzvf $TGZ;swift build;swift test"
