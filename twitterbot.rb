#!/usr/local/bin/ruby -Ku
# -*- coding: utf-8 -*-

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
  include Twitter

  def initialize (screen_name, pass, logdest=STDOUT)
    @debug = false
    @logger = Logger.new(logdest, 5)

    @screen_name = screen_name
    httpauth = HTTPAuth.new(screen_name, pass)
    @twit = Base.new(httpauth) 
  end

  def set_debug
    @debug = true
  end

  def tweet(msg)
    begin
      unless @debug
        blog_title = blog_title.split(//u)[0,130].join + "..." if msg.split(//u).size > 140
        @twit.update(msg)
      else
        p msg
      end
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
  # @myself が先頭mentionedにReTweetする
  #
  # TODO: 最後にReTweetした元TweetのIDを見てるので、mentioned取得のオーダーが変わると
  # 再ReTweetしてしまう。IDをDBに保存すべき
  #
  def retweet_to_mentioned
    flag = false
    tmp_id = 0

    begin
      @twit.mentions.each {|status|
        break if status.id == @last_mentioned_id
#	next if status.user.screen_name == @screen_name # skip tweet by myself

        # check if the tweet start with @myself
        if /^@#{@screen_name}/ =~ status.text
          if !flag
            tmp_id = status.id
            flag = true
          end

          tweet("RT " + "@" + status.user.screen_name + " : " +  status.text.gsub("@" + @screen_name, ""))
        end
      }
    rescue => e
      @logger.error e.message
    end
    if flag
      @last_mentioned_id = tmp_id
    end
  end

  #
  # public timeline を検索し、ヒットしたTweetをReTweetする
  #
  def search_and_retweet searchkey
    flag = false
    tmp_id = 0

    begin
      Twitter::Search.new(searchkey).each {|status|
      #@twit.search(searchkey).each {|status|
        break if status.id == @last_searched_id
	next if @screen_name == status.from_user

	# RT only when it has searchkey before RT/QT
	indexes = {status.text.index("RT"), status.text.index("QT")}
	index = indexes.min
	next if status.text.slice(0, index).index(searchkey) == nil

        if !flag
          tmp_id = status.id
          flag = true
        end
        tweet("RT " + "@" + status.from_user + " " +  status.text)
      }
    rescue => e
      @logger.error e.message
    end
    if flag
      @last_searched_id = tmp_id
    end
  end

  #
  # TODO ファイル一つにまとめる、DB化する
  #
  def follow_back
    @friends = @twit.friend_ids
    @followers = @twit.follower_ids

    new_follower = @followers - @friends

    new_follower.each {|id|
      begin
        @twit.friendship_create id
        p id
      rescue => e
        @logger.warn e.message
      end
    }
    new_follower
  end


  def remove_back
    @friends = @twit.friend_ids
    @followers = @twit.follower_ids

    removed = @friends - @followers
    removed.each {|id|
      begin
        @twit.friendship_destroy id
      rescue => e
        @logger.warn e.message
      end
    }
    removed
  end

  def save_status
    begin
      open("botstatus.dat", "w") {|f|
        f.puts @last_mentioned_id
      }
      open("last_searched_id.dat", "w") {|f|
        f.puts @last_searched_id
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
      open("last_searched_id.dat", "r") {|f|
        data = f.readlines
        @last_searched_id = data[0].to_i
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
  bot.set_debug
  bot.load_status
  bot.tweet "Hello Bot World at " + Time.now.to_s
#  bot.tweet_random "random.txt"
#  bot.retweet_to_mentioned
#  bot.follow_back
#  bot.remove_back
  bot.search_and_retweet "東京"
  bot.save_status

rescue => e
  logger = Logger.new("./twitterbot.log", 5)
  logger.error e.message
end

end

