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

# 定义一个哈希表来保存区域对应的互斥锁
#area_locks = Hash.new { |hash, key| hash[key] = Mutex.new }
# 定义一个互斥锁，用于保护文件写入操作
file_lock = Mutex.new

# 创建线程池
thread_pool = []
file=File.open("全国终结补全2.csv","w+")
bom = "\xEF\xBB\xBF" # Byte Order Mark
file.write bom
file.puts "省,市,区,全名,别名,电话,地址"
file.flush
counter=10000
start_counter=10000


uri="http://yyk.99.com.cn/city.html"

#全部
doc=loadDoc(uri)
content=doc.css("ul.m-tab-bd").css("li")[0]
#全部省[省]
shengc=content.css("dt a")
#全部市[[市],[]]
shic=content.css("dd")

#多少个省
shengs=shengc.size


#省循环
for i in 0..shengs-1 do
  #市解析[市]
  shia=shic[i].css("a")
  size=shia.size
  #省名出来了
  sheng=shengc[i].text

  for j in 0..size-1 do
    if(i==0)
      #直辖市（用市名代替省名）
      sheng=shia[j].text
    end
    #市名出来了
    shi=shia[j].text


    #请求市页面
    uri2="http://yyk.99.com.cn"+shia[j].attribute("href")
    doc2=loadDoc(uri2)
    next unless doc2
    #[（0没用）[区，[医院]]]
    fl=doc2.css("div.m-box")
    #[区]
    quc=fl.css("h3 span")
    len2=quc.size


    #迭代区
    for k in 0..len2-1 do
      qu=quc[k].text.lstrip.rstrip

      # 使用区域对应的互斥锁
      #area_locks[qu].synchronize do
      #医院[]
      yiyuanc=fl[k+1].css("td")
      next unless yiyuanc
      siz2=yiyuanc.size
        #开线程
      thread_pool << Thread.new(yiyuanc,sheng,shi,qu,siz2) do | yiyuanc,sheng,shi,qu,siz2 |
        #迭代医院
        for ii in 0..siz2-1 do
            uri3=yiyuanc[ii].css("a").attribute("href")

              #医院
              doc3=loadDoc("http://yyk.99.com.cn"+uri3)
              next unless doc3
              #医院
              yiyuan=doc3.css("div.header_box").css("div.header_left b").text.lstrip
              next if yiyuan.empty?
              lis3=doc3.css("div.wrap_intro li")

                unless lis3[0]
                  putc 'x'
                  # 互斥锁保护文件写入操作
                  file_lock.synchronize do
                    file.puts sheng+","+shi+","+qu+","+yiyuan+",,,"
                  end
                else
                  putc "."
                  altName=doc3.css("div.intro_text p").text.gsub("医院别名：","")
                  #altName=lis3[0].text.gsub("医院别名：","")
                  level=lis3[0].text.gsub("医院电话：","")
                  addr=lis3[3].text.gsub("医院地址：","")
                  # 互斥锁保护文件写入操作
                  file_lock.synchronize do
                    file.puts sheng+","+shi+","+qu+","+yiyuan+","+altName+","+level+","+addr
                    file.flush
                  end
                end
          #end
        end
      end
    end
  end
end
# 等待所有线程执行完毕
thread_pool.each(&:join)

file.close
