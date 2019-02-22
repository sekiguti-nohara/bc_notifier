require "nokogiri"
require "mechanize"
require "json"
require 'date'
require 'slack-notifier'

AIR_SHIFT_URL = "https://connect.airregi.jp/login?client_id=SFT&redirect_uri=https%3A%2F%2Fconnect.airregi.jp%2Foauth%2Fauthorize%3Fclient_id%3DSFT%26redirect_uri%3Dhttps%253A%252F%252Fairshift.jp%252Fsft%252Fcallback%26response_type%3Dcode"

slack_mension_name = {
  # hashでnameとmensionするための番号を入れる
  "野原将人" => "UA7GB6H6Z",
  "関口翔太" => "U9RB1EWCQ",
  "古屋哲人" => "U9RQZ8Q0N",
  "小野聡之" => "UCPQZD83X",
  "西川譲" => "UAG244L84",
  "小野瀬萌" => "U7QUMPFMX",
  "脇坂翔" => "U9SN5S005",
  "峯村開" => "U7ZGS5YJJ",
  "中村直人" => "U88JSL39D",
  "山本健太" => "U9RV1HH1N",
  "吉富晃也" => "UCAQ1BCDA",
  "大内泰良" => "UCGLEE6DB",
  "渡辺樹" => "UCF3ZRCUR",
}

agent = Mechanize.new
agent.user_agent_alias = 'Mac Safari 4'
agent.get(AIR_SHIFT_URL) do |page|

  #データをスクレイピング
  mypage = page.form_with(id: 'command') do |form|
    form.username = ENV["AIR_SHIFT_USERNAME"]
    form.password = ENV["AIR_SHIFT_PASSWORD"]
  end.submit
  air_shift_html_data = Nokogiri::HTML(mypage.content.toutf8)
  json_data = air_shift_html_data.xpath("//script")[3]["data-json"]
  hash_data = JSON.parse json_data

  #必要な情報だけを整形する
  staffs = hash_data["app"]["staffList"]["staff"]
  shifts = hash_data["app"]["monthlyshift"]["shift"]["shifts"]
  today_bc_shifts = shifts.select { |shift| shift["date"] == (Date.today).strftime("%Y%m%d") && shift["groupId"].to_i == 8375}
  today_bc_mentors = today_bc_shifts.map{ |shift| staffs.select { |staff| staff["id"] == shift["staffId"] }}

  #slackに投稿する
  notifier = Slack::Notifier.new(ENV["SLACK_POST_URL"])
  notifier.ping("BC") if today_bc_shifts.any?
  today_bc_mentors.zip(today_bc_shifts).each do |today_bc_mentor,shift|
    mention_id = slack_mension_name[today_bc_mentor[0]["name"]["family"] + today_bc_mentor[0]["name"]["first"]]
    start_hour = shift["workTime"]["text"][-13,2]
    start_minute = shift["workTime"]["text"][-10,2]
    end_hour = shift["workTime"]["text"][-5,2]
    end_minute = shift["workTime"]["text"][-2,2]
    notifier.ping("<@#{mention_id}>:#{start_hour}:#{start_minute}~#{end_hour}:#{end_minute}")
  end

end
