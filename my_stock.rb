#!/usr/bin/env ruby
# encoding: UTF-8

require 'http'
require 'awesome_print'

Struct.new('Stock', :code, :name, :current_price, :current_diff_price, :current_diff_percentage)
Struct.new('MyStock',
           :code,
           :name,
           :amount,
           :current_price,
           :price,
           :current_diff_price,
           :diff_price,
           :current_diff_percentage,
           :diff_percentage,
           :current_change,
           :change,
           :current_total,
           :total)

def get_stocks(stock_codes)
  codes_str = stock_codes.map(&->(c) { "s_#{c}" }).join(',')
  Http
    .get("http://hq.sinajs.cn/rn=#{srand}&list=#{codes_str}").to_s.encode(Encoding::UTF_8, Encoding::GBK)
    .split(';')
    .map do |r|
      groups = r.scan(/var hq_str_s_(.*)="(.*)"/).first
      if groups
        params = groups[1].split(',').first(4)
        Struct::Stock.new(groups[0], params[0], *params.last(3).map(&->(param) { param.to_f }))
      end
    end
    .compact
end

def color_float(f)
  s_f = sprintf "%.3f", f
  case
  when f > 0 then s_f.red
  when f == 0 then s_f
  when f < 0 then s_f.green
  end
end

def format_stock(stock)
  additional_name_size = stock.name.split('').map { |c| c =~ /[a-zA-Z]/ }.compact.size
  # TODO: confirmation requires
  name_size = 10 + (additional_name_size > 0 ? 2 * additional_name_size - 1 : 0)
  stock.instance_eval do
    sprintf "%#{name_size}s: %10.3f %10.3f %21s%%",
      name,
      current_price,
      current_diff_price,
      color_float(current_diff_percentage)
  end
end

def format_my_stock(stock)
  additional_name_size = stock.name.split('').map { |c| c =~ /[a-zA-Z]/ }.compact.size
  # TODO: confirmation requires
  name_size = 10 + (additional_name_size > 0 ? 2 * additional_name_size - 1 : 0)
  stock.instance_eval do
    sprintf "%#{name_size}s: %10d %10.3f(%7.3f) %10.3f(%7.3f) %21s%%(%18s%%) %10.3f(%10.3f) %10.3f(%9.3f)",
      name,
      amount,
      current_price, price,
      current_diff_price, diff_price,
      color_float(current_diff_percentage), color_float(diff_percentage),
      current_change, change,
      current_total, total
  end
end

loop do
  begin
    index_codes = %w( sh000001 sz399001 sz399006 )
    stock_codes = %w( sh600705 sh600343 sz000601 sh600795 sz150176 sh502008 )
    amounts     = [   1500,    100,     1300,    400,     400,     1400     ]
    prices      = [   31.098,  39.891,  11.505,  7.366,   1.650,   1.265    ]

    stocks = get_stocks(index_codes + stock_codes)
    stock_dict = stocks.map { |s| [s.code, s] }.to_h

    index_output = index_codes.map(&->(c) { format_stock(stock_dict[c]) }).join("\n")
    my_stocks = stock_codes.zip(amounts, prices)
                           .map(
                             &->(l) do
                               Struct::MyStock.new.tap do |s|
                                 s.code, s.amount, s.price = l
                               end
                             end
                           )
                           .map(
                             &->(my_stock) do
                               stock = stock_dict[my_stock.code]
                               stock.members.each { |m| my_stock[m] = stock[m] }
                               my_stock.tap do |s|
                                 s.diff_price = s.current_price - s.price
                                 s.diff_percentage = (s.current_price - s.price) * 100 / s.price
                                 s.change = s.amount * s.diff_price
                                 s.current_change = s.amount * s.current_diff_price
                                 s.total = s.amount * s.price
                                 s.current_total = s.amount * s.current_price
                               end
                             end
                           )
                           .map(
                             &->(my_stock) do
                               my_stock
                             end
                           )
                           .sort_by(&:total)
                           .reverse
    stock_output = my_stocks.map(&->(my_stock) { format_my_stock(my_stock) }).join("\n")

    system('clear')

    puts index_output

    puts
    printf "%24s %15s %13s %15s %14s %13s\n", *%w(持仓 现价(成本) 差价(成本差价) 差价%(成本差价%) 总差价(成本总差价) 总持仓(成本总持仓))
    puts stock_output

    puts
    change = my_stocks.reduce(0) { |sum, s| sum + s.change }
    current_change = my_stocks.reduce(0) { |sum, s| sum + s.current_change }
    total = my_stocks.reduce(0) { |sum, s| sum + s.total }
    current_total = my_stocks.reduce(0) { |sum, s| sum + s.current_total }
    printf "%14s: %61.3f%%(%7.3f%%) %10.3f(%10.3f) %10.3f(%9.3f)\n",
      'TOTAL',
      current_change * 100 / (current_total - current_change), change * 100 / total,
      current_change, change,
      current_total, total

    sleep 3
  rescue Errno::ENETDOWN, SocketError, Errno::ETIMEDOUT, Errno::ECONNREFUSED, IOError, Errno::ENETUNREACH
    sleep 3
    retry
  rescue Interrupt
    break
  end
end
