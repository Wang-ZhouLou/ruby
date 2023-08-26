#!/usr/bin/env ruby
require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'pp'

require 'thread'  # 导入线程库



def loadDoc(uri)
    retryCount=5
    begin
        file=URI.open(uri, 'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/58.0.3029.110 Safari/537.3')
        text=file.read
       # puts text
        #把encoding设置为真正的encoding
        text.force_encoding("utf-8")
        #把文件中的encoding改成正确的
        #text.gsub!("gb2312","utf-8")
        doc=Nokogiri::HTML(text)
        return doc
    rescue Exception => e
        retryCount=retryCount-1
        if retryCount==0
            puts e.message
            return nil
        end
        retry
    end
end


def sanitize_filename(filename)
    filename.gsub(/[\/\\:\*\?"<>\|]/, '_')  # 将非法字符替换为下划线
end



# 定义一个互斥锁，用于保护文件写入操作
file_lock = Mutex.new

# 创建线程池
thread_pool = []

uri="http://yyk.99.com.cn/city.html"
#全部
doc=loadDoc(uri)
content=doc.css("ul.m-tab-bd")[0]

#全部省[]
h4s=content.css("dt a")

#全部市【】
uls=content.css("dd")
#多少个省
length=h4s.length


file=File.open("全国医院.csv","w+")
bom = "\xEF\xBB\xBF" # Byte Order Mark
file.write bom
file.puts "省,市,区,全名,别名,电话,地址"
file.flush

counter=10000
start_counter=10000
for i in 0..length-1

    #市解析
    as=uls[i].css("a")
    size=as.size
    #省出来了
    prv=h4s[i].text

    for j in 0..size-1
        #省出来了
        prv=as[j].text if(i==0)
        #市出来了
        city=as[j].text


        uri2="http://yyk.99.com.cn"+as[j].attribute("href")
        doc2=loadDoc(uri2)
        next unless doc2

        #区出来了
        fl=doc2.css("div.m-box")
        as5=fl.css("h3 span")
        next unless as5
        len2=as5.length

        #迭代区
        for k in 0..len2-1
            counter=counter+1
            next if counter<start_counter

            thread_pool << Thread.new(prv,city) do | prv,city|

                district=as5[k].text.lstrip.rstrip
                #医院
                as2=fl[k].css("td a")
                siz2=as2.size

                for ii in 0..siz2-1
                    uri3=as2[ii].attribute("href")

                    #医院
                    doc3=loadDoc("http://yyk.99.com.cn"+uri3)
                    next unless doc3
                        realName=doc3.css("div.wrap_title b").text.lstrip
                        lis3=doc3.css("div.wrap_text p")
                        unless lis3[0]
                            puts prv+","+city+","+district+","+realName+",,,"
                            # 互斥锁保护文件写入操作
                            file_lock.synchronize do
                                file.puts prv+","+city+","+district+","+realName+",,,"
                            end
                            putc 'x'
                        else
                            altName=lis3[0].text.gsub("医院别名：","")
                            level=lis3[2].text.gsub("医院电话：","")
                            addr=lis3[3].text.gsub("医院地址：","")
                            puts prv+","+city+","+district+","+realName+","+altName+","+level+","+addr
                            # 互斥锁保护文件写入操作
                            file_lock.synchronize do
                                file.puts prv+","+city+","+district+","+realName+","+altName+","+level+","+addr
                                file.flush
                            end
                            putc "."
                        end
                end
            end
        end
    end
end

# 等待所有线程执行完毕
thread_pool.each(&:join)

file.close
