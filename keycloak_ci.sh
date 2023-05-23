#!/usr/bin/bash

echo "Build: Build Keycloak"
MVN_HTTP_CONFIG="-Dhttp.keepAlive=false -Dmaven.wagon.http.pool=false -Dmaven.wagon.http.retryHandler.class=standard -Dmaven.wagon.http.retryHandler.count=3 -Dmaven.wagon.httpconnectionManager.ttlSeconds=120"
mvn clean install dependency:resolve -nsu -B -e -DskipTests -DskipExamples $MVN_HTTP_CONFIG > build_keycloak.log 2>&1

echo "Base UT: Run unit tests"
SEP=""
PROJECTS=""
for i in `find -name '*Test.java' -type f | egrep -v './(testsuite|quarkus|docs)/' | sed 's|/src/test/java/.*||' | sort | uniq | sed 's|./||'`; do
	PROJECTS="$PROJECTS$SEP$i"
	SEP=","
done
mvn test -nsu -B -pl "$PROJECTS" -am > base_ut.log 2>&1

echo "Base IT: Run base tests"
SUREFIRE_RERUN_FAILING_COUNT=2
for i in {1..6}; do
	TESTS=`testsuite/integration-arquillian/tests/base/testsuites/base-suite.sh $i`
	echo "Tests: $TESTS"
	for j in `echo $TESTS | sed 's/,/ /g'`; do
		SUFFIX=`echo $j | cut -d '.' -f 4`
		echo ${j}:${SUFFIX}
		mvn test -Dsurefire.rerunFailingTestsCount=${SUREFIRE_RERUN_FAILING_COUNT} -nsu -B -Pauth-server-quarkus -Dtest=$j -pl testsuite/integration-arquillian/tests/base > base_it_${i}_${SUFFIX}.log 2>&1
	done
done

echo "Account Console IT: Run Account Console IT"
BROWSER=chrome
CHROMEWEBDRIVER=/usr/local/bin
mvn test -Dsurefire.rerunFailingTestsCount=${SUREFIRE_RERUN_FAILING_COUNT} -nsu -B -Pauth-server-quarkus -Dtest=**.account2.**,!SigningInTest#passwordlessWebAuthnTest,!SigningInTest#twoFactorWebAuthnTest -Dbrowser=${BROWSER} "-Dwebdriver.chrome.driver=$CHROMEWEBDRIVER/chromedriver" -f testsuite/integration-arquillian/tests/other/base-ui/pom.xml > account_console_it.log 2>&1

