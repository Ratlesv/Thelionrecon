#! /bin/bash 
url=$1

figlet "TheLionRecon" | lolcat
echo "                 @Abbas Cyber Security    " | lolcat

if [ ! -d "$url" ]; then
      mkdir $url
fi
if [ ! -d "$url/recon" ]; then
      mkdir $url/recon
fi

if [ ! -d "$url/params_vuln" ]; then
          mkdir $url/params_vuln
fi

if [ ! -d "$url/subs_vuln" ]; then
          mkdir $url/subs_vuln
fi

if [ ! -d "$url/subs_vuln/false_positive" ]; then
          mkdir $url/subs_vuln/false_positive
fi

if [ ! -d "$url/params_vuln/false_positive" ]; then
          mkdir $url/params_vuln/false_positive
fi

if [ ! -d "$url/recon/EyeWitness" ]; then
      mkdir $url/recon/EyeWitness
fi



#---------------------------------------------------------------------------------
#-----------------------------Finding SubDomains----------------------------------
#----------------------------------------------------------------------------------
echo "[+]Enumurating SubDomains Using Amass..." | lolcat
amass enum -d $url >> $url/recon/amass.txt
cat $url/recon/amass.txt | grep $url >> $url/recon/final.txt
rm $url/recon/amass.txt

echo "[+]Enumurating SubDomains Using Assetfinder..." | lolcat
assetfinder $url >> $url/recon/assetfinder.txt
cat $url/recon/assetfinder.txt | grep $url >> $url/recon/final.txt
rm $url/recon/assetfinder.txt

echo "[+]Enumurating SubDomains Using SubFinder..." | lolcat
subfinder -d $url -o $url/recon/subfinder.txt
cat $url/recon/subfinder.txt | grep $url >> $url/recon/final.txt
rm $url/recon/subfinder.txt

echo "[+]Enumurating SubDomains Using Findomain..." | lolcat
findomain -t $url -q >> $url/recon/findomain.txt
cat $url/recon/findomain.txt | grep $url >> $url/recon/final.txt
rm $url/recon/findomain.txt

echo "[+]Enumurating SubDomains Using Sublist3r..." | lolcat
python3 /opt/Sublist3r/sublist3r.py -d $url -o $1/recon/sublist3r.txt
cat $url/recon/sublist3r.txt | grep $url >> $url/recon/final.txt
rm $1/recon/sublist3r.txt 

echo "[+]Filtering Repeated Domains........." | lolcat
cat $url/recon/final.txt | sort -u | tee $url/recon/final_subs.txt 
rm $url/recon/final.txt 

echo "[+]Total Unique SubDomains" | lolcat
cat $url/recon/final_subs.txt | wc -l
#--------------------------------------------------------------------------------------------------
#-----------------------------------Filtering Live SubDomains--------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Removing Dead Domains Using httpx....." | lolcat
cat $url/recon/final_subs.txt | httpx --silent | sed 's/https\?:\/\///' >> $url/recon/live_check.txt

echo "[+]Removing Dead Domains Using httprobe....." | lolcat
cat $url/recon/final_subs.txt | httprobe | sed 's/https\?:\/\///' >> $url/recon/live_check.txt

echo "[+]Analyzing Both httpx & httprobe....."
cat $url/recon/live_check.txt | sort -u | tee $url/recon/live_subs.txt 

echo "[+]Total Unique Live SubDomains....."
cat $url/recon/live_subs.txt | wc -l

#------------------------------------------------------------------------------------------------------------
#--------------------------------------Taking LiveSubs ScreenShots-------------------------------------------
#------------------------------------------------------------------------------------------------------------
#echo "[+]Taking ScreenShots For Live Websites..." | lolcat
#python3 /opt/EyeWitness/Python/EyeWitness.py -f $1/recon/livesubs.txt --no-prompt -d $1/recon/EyeWitness --timeout 240

#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For SubDomain TakeOver------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Testing For SubTakeOver" | lolcat
subzy --targets  $url/recon/final_subs.txt  --hide_fails >> $url/subs_vuln/sub_take_over.txt
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For Open Ports------------------------------------
#--------------------------------------------------------------------------------------------------
#echo "[+] Scanning for open ports..."
#nmap -iL $url/recon/livesubs.txt -T4 -oA $url/recon/openports.txt
#--------------------------------------------------------------------------------------------------
#-----------------------------------Enumurating Parameters-----------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Enumurating Params From Paramspider...." | lolcat
python3 /opt/Paramspider/paramspider.py --level high -d $url -p noor -o $1/recon/params.txt
echo "[+]Enumurating Params From Waybackurls...." | lolcat
cat $1/recon/live_subs.txt | waybackurls | grep = | qsreplace noor >> $url/recon/params.txt
echo "[+]Enumurating Params From gau Tool...." | lolcat
gau --subs  $url | grep = | qsreplace noor >> $url/recon/params.txt 
echo "[+]Enumurating Params From gauPlus Tool...." | lolcat
cat $url/recon/live_subs.txt | gauplus | grep = | qsreplace noor >> $url/recon/params.txt

echo "[+]Filtering Dups..." | lolcat
cat $url/recon/params.txt | sort -u | tee $url/recon/final_params.txt 

rm $url/recon/params.txt

echo "[+]Total Unique Params Found" | lolcat
cat $url/recon/final_params.txt | wc -l
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For Open Redirects----------------------------------------
#--------------------------------------------------------------------------------------------------
#echo "[+]Testing For Openredirects" | lolcat
#cat $url/recon/final_params.txt | qsreplace 'http://evil.com' | while read host do ; do curl -s -L $host -I | grep "evil.com" && echo "$host" ;done >> $url/params_vuln/open_redirect.txt
#--------------------------------------------------------------------------------------------------
#-----------------------------------Checking For SSRF----------------------------------------------
#--------------------------------------------------------------------------------------------------
#echo "[+]Testing For External SSRF.........." | lolcat
#cat $url/recon/final_params.txt | qsreplace "https://noor.requestcatcher.com/test" | tee $url/recon/ssrftest.txt && cat $url/recon/ssrftest.txt | while read host do ; do curl --silent --path-as-is --insecure "$host" | grep -qs "request caught" && echo "$host \033[0;31mVulnearble\n"; done >> $url/params_vuln/eSSRF.txt
#rm $url/recon/ssrftest.txt
#--------------------------------------------------------------------------------------------------
#-------------------------------Checking For HTMLi && RXSS-----------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Testing For HTML Injection...." | lolcat
cat $url/recon/final_params.txt | qsreplace '"><u>hyper</u>' | tee $url/recon/temp.txt && cat $url/recon/temp.txt | while read host do ; do curl --silent --path-as-is --insecure "$host" | grep -qs "<u>hyper</u>" && echo "$host \033[0;31mVulnearble\n"; done > $url/params_vuln/htmli.txt
#--------------------------------------------------------------------------------------------------
#-----------------------------------Checking For Clickjacking--------------------------------------
#--------------------------------------------------------------------------------------------------
#echo "[+]Checking For Clickjacking...." | lolcat
#cat $url/recon/live_subs.txt | while read host do ; do curl -I -L --silent --path-as-is --insecure "$host" | grep -qs "x-frame-options" && echo "$host \033[0;31mNot\n" || echo  "$host  \033[0;31mVulnerable" ; done | grep Vulnerable >> $url/subs_vuln/false_positive/clickjack.txt
#------------------------------------------------------------------------------------------------------------
#----------------------------------------------Checking For CORS---------------------------------------------
#------------------------------------------------------------------------------------------------------------
#echo "[+]Checking For CORS...." | lolcat
#cat $url/recon/live_subs.txt | while read host do ; do curl $host --silent --path-as-is --insecure -L -I -H Origin:beebom.com | grep "beebom.com" && echo "$host" ; done >> $url/subs_vuln/cors.txt
#------------------------------------------------------------------------------------------------------------
#--------------------------------------Checking For XSS through Referer Header-------------------------------
#------------------------------------------------------------------------------------------------------------
echo "[+]Checking For Xss in Referer Header...." | lolcat
cat $url/recon/live_subs.txt | while read host do ; do curl $host --silent --path-as-is --insecure -L -I -H Referer:https://beebom.com/ | grep "beebom.com" && echo "$host" ; done >> $url/subs_vuln/xss_refer.txt
#--------------------------------------------------------------------------------------------------
#-------------------------------------Full Scan With Nuclei----------------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+] Full Scan With Nuclei" | lolcat
cat $url/recon/live_subs.txt | nuclei -t /root/nuclei-templates/ >> $url/recon/nuclei.txt



#--------------------------------------------------------------------------------------------------
#---------------------------Checking For Sql Injection Vulnerability-------------------------------
#--------------------------------------------------------------------------------------------------
echo "[+]Testing For Sqli" | lolcat
cat $url/recon/final_params.txt | python3 /opt/sqlmap/sqlmap.py
#------------------------------------------------------------------------------------------------------------
#---------------------------------Checking For Open redirects through X-Forwarded Header---------------------
#------------------------------------------------------------------------------------------------------------

#------------------------------------------------------------------------------------------------------------
#--------------------------------------Checking For CRLF Injection-------------------------------------------
#------------------------------------------------------------------------------------------------------------



