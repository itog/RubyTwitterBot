#!/usr/local/bin/ruby -Ku

#
# Twitter Bot Program
#

require 'rubygems'
require 'twitter'
require 'pp'
require 'logger'

if RUBY_VERSION < '1.9.0'
  class Array
    def choice
      at( rand( size ) )
    end
  end
end


#add mentions method to Twitter::Base class
module Twitter
  class Base
    def mentions(query={})
      perform_get('/statuses/mentions.json', :query => query)
    end
  end
end


#
# TwitterBot class
#
class TwitterBot
  def initialize (screen_name, pass, logdest=STDOUT)
    @logger = Logger.new(logdest, 5)

    @screen_name = screen_name
    httpauth = Twitter::HTTPAuth.new(screen_name, pass)
    @twit = Twitter::Base.new(httpauth) 
  end

  def tweet(msg)
    begin
      @twit.update(msg)
    rescue => e
      @logger.error e.message
    end
  end

  def tweet_random(filename)
    begin
      open(filename, "r") {|f|
        scripts = f.readlines
        tweet scripts.choice
      }
    rescue => e
      @logger.error e.message
    end
  end

  #
  # TODO: @name が先頭のものにだけReTweetするようにしたほうがいいかも
  #
  def retweet_to_mentioned
    flag = false
    tmp_id = 0

    begin
      @twit.mentions.each {|status|
        break if status.id == @last_mentioned_id
	next if status.user.screen_name == @screen_name
        if !flag
          tmp_id = status.id
          flag = true
        end

        tweet("RT " + "@" + status.user.screen_name + " : " +  status.text.gsub("@" + @screen_name, ""))
      }
    rescue => e
      @logger.error e.message
    end
    if flag
      @last_mentioned_id = tmp_id
    end
  end

  def save_status
    begin
      open("botstatus.dat", "w") {|f|
        f.puts @last_mentioned_id
      }
    rescue => e
      @logger.error "file save error"
    end
  end
  def load_status
    begin
      open("botstatus.dat", "r") {|f|
        data = f.readlines
        @last_mentioned_id = data[0].to_i
      }
    rescue => e
      @logger.error "file load error"
    end
  end
end


#
# Sample Bot Application
#

if $0 == __FILE__

begin
  screen_name = ""
  password =  ""
  open("account.cfg", "r") {|f|
    account = f.readlines
    screen_name = account[0].strip
    password = account[1].strip
  }

  bot = TwitterBot.new(screen_name, password)
  bot.load_status
  bot.tweet "Hello Bot World at " + Time.now.to_s
#  bot.tweet_random "random.txt"
#  bot.retweet_to_mentioned
  bot.save_status

rescue => e
  logger = Logger.new("./twitterbot.log", 5)
  logger.error e.message
end

end

