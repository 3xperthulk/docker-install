#!/bin/bash
rm ./Dockerfile
read -p "Enter your OS - Available OS centos,ubuntu: " os
read -p "Enter the jdk version :" jdkversion

read -a array -p "Enter the name of images: "
echo "Hello, $name"
echo "Hello, $jdkversion"

if [[ $os == 'centos' ]]
then 
cat << EOF > Dockerfile
FROM centos
MAINTAINER hello@gritfy.com
RUN mkdir /opt/tomcat/webapps
WORKDIR /opt/tomcat
RUN curl -O https://www-eu.apache.org/dist/tomcat/tomcat-8/v8.5.40/bin/apache-tomcat-8.5.40.tar.gz
RUN tar xvfz apache*.tar.gz
RUN mv apache-tomcat-8.5.40/* /opt/tomcat/.
RUN yum -y install $jdkversion
RUN java -version
EOF
elif [[ $os == 'ubuntu' ]]
then
cat << EOF > Dockerfile
FROM centos
MAINTAINER hello@gritfy.com
RUN mkdir /opt/tomcat/webapps
WORKDIR /opt/tomcat
RUN curl -O https://www-eu.apache.org/dist/tomcat/tomcat-8/v8.5.40/bin/apache-tomcat-8.5.40.tar.gz
RUN tar xvfz apache*.tar.gz
RUN mv apache-tomcat-8.5.40/* /opt/tomcat/.
RUN yum -y install $jdkversion
RUN java -version
EOF
else
echo "Please provide valid arguments"
fi
#Default image creation without wars

read -p "Do you want to Build Multiple Images for selected Packages or Single Image. Please enter y/n" build
for n in ${array[*]};
do
  if [[ $build == 'y' ]]
  then 
    echo "COPY $n.war /opt/tomcat/webapps/" >> ./Dockerfile."$n"
    docker build -t $n ./Dockerfile."$n"
  else
    echo "COPY $n.war /opt/tomcat/webapps/" >> ./Dockerfile
  fi
done
if [[ $build == 'n' ]]
then
docker build -t sample ./Dockerfile
fi
