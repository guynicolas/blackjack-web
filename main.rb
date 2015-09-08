require 'rubygems'
require 'sinatra'

use Rack::Session::Cookie, :key => 'rack.session',
                           :path => '/',
                           :secret => 'your_secret' 

helpers do 
  def calculate_total(cards)
    card_values = cards.map {|card| card[1]}
    total = 0
    card_values.each do |value| 
      if value == 'A'
        total += 11
      else 
        total += value.to_i == 0 ? 10 : value.to_i
      end 
    end 
    #Correcting for Aces 
    card_values.select {|value| value == 'A'}.count.times do 
      break if total <= 21
      total -= 10
    end 
    return total
  end  

  def card_image(card)
    suit = case card[0]
      when 'C' then 'clubs'
      when 'S' then 'spades'
      when 'H' then 'hearts'
      when 'D' then 'diamonds'
    end 
    value = card[1]
    if ['Q', 'J', 'K', 'A'].include?(value)
      value = case card[1] 
        when 'Q' then 'queen'
        when 'J' then 'jack'
        when 'K' then 'king'
        when 'A' then 'ace'
      end 
    end 
    "<img src='/images/cards/#{suit}_#{value}.jpg' class='card_image'>"
  end

  def winner!(msg)
    @show_dealer_hit_button = false 
    @show_hit_or_stay_buttons = false 
    @play_again = true 
    session[:player_pot] += session[:player_bet].to_i
    @winner = "<strong>#{session[:player_name]} wins!</strong> #{msg} #{session[:player_name]} now has #{session[:player_pot]}"
  end

  def tie!(msg)
    @show_dealer_hit_button = false 
    @show_hit_or_stay_buttons = false 
    @play_again = true 
    @tie = "<strong>It's a tie!</strong> #{msg} #{session[:player_name]} still has #{session[:player_pot]}"
  end
  def loser!(msg)
    @show_dealer_hit_button = false 
    @show_hit_or_stay_buttons = false 
    @play_again = true 
    session[:player_pot] -= session[:player_bet].to_i
    @loser = "<strong>#{session[:player_name]} loses!</strong> #{msg} #{session[:player_name]} now has #{session[:player_pot]}."
  end 
end 

before do 
  @show_hit_or_stay_buttons = true 
  @show_dealer_hit_button = false 
end 
get '/' do 
  if session[:player_name] 
    redirect '/bet'
  else 
    redirect '/new_player'
  end 
end 

get '/new_player' do 
  session[:player_pot] = 500
  erb :new_player
end 

post '/new_player' do 
  if params[:player_name].empty? 
    @loser = "You must enter a name!"
    halt erb(:new_player)
  else  
    session[:player_name] = params[:player_name]
    redirect '/bet'
  end 
end 

get '/bet' do 
  session[:player_bet] = nil 
  erb :bet
end 

post '/bet' do 
  if params[:bet_amount].nil? || params[:bet_amount].to_i == 0
    @loser = "You have to place a bet."
    halt erb(:bet)
  else  
    session[:player_bet] = params[:bet_amount]
    redirect '/game'
  end 
end 

get '/game' do 
  session[:turn] = session[:player_name]
  #Initializing deck
  suits = ['H', 'C', 'D', 'S']
  values = ['2', '3', '4', '5', '6', '7', '8', '9', '10', 'Q', 'J', 'K', 'A']
  session[:deck] = suits.product(values).shuffle!

  #Dealing initial cards
  session[:player_cards] = []
  session[:dealer_cards] = []
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop
  session[:player_cards] << session[:deck].pop
  session[:dealer_cards] << session[:deck].pop

  #Checking for BlackJAck
  player_total = calculate_total(session[:player_cards])
  if player_total == 21
    winner!("#{session[:player_name]} hit BlackJack.!")
  end 

  erb :game 
end 

post '/game/player/hit' do 
  session[:player_cards] << session[:deck].pop 
  player_total = calculate_total(session[:player_cards])

  if player_total > 21
    loser!("#{session[:player_name]} busted at #{player_total}.")
  elsif player_total == 21
    winner!("#{session[:player_name]} hit BlackJack.")
  end 
  erb :game, layout: false 
end 

post '/game/player/stay' do 
  redirect '/game/dealer'
end 

get '/game/dealer' do 
  session[:turn] = 'Dealer'
  @show_hit_or_stay_buttons = false 

  dealer_total = calculate_total(session[:dealer_cards])
  if dealer_total > 21
    winner!("Dealer busted at #{dealer_total}.")
  elsif dealer_total == 21
    loser!("Dealer hit BlackJack!")
  elsif dealer_total >= 17 # 17, 18, 19 and 20 
    redirect '/game/dealer/stay'
  else 
    redirect '/game/dealer/hit'
  end 
  erb :game, layout: false 
end 

get '/game/dealer/hit' do 
  @show_hit_or_stay_buttons = false 
  @show_dealer_hit_button = true 
  erb :game, layout: false 
end 

post '/game/dealer/hit' do
  session[:dealer_cards] << session[:deck].pop 
  redirect '/game/dealer'
end

get '/game/dealer/stay' do
  redirect '/game/compare'
end

get '/game/compare' do
  dealer_total = calculate_total(session[:dealer_cards])
  player_total = calculate_total(session[:player_cards])

  if dealer_total == player_total 
    tie!("#{session[:player_name]} and Dealer stayed at #{player_total}.")
  elsif dealer_total < player_total
    winner!("#{session[:player_name]} stayed at #{player_total} and Dealer stayed at #{dealer_total}.")
  else 
    loser!("#{session[:player_name]} stayed at #{player_total} and Dealer stayed at #{dealer_total}.")
  end 
  erb :game, layout: false 
end

get '/game_over' do 
  erb :game_over
end 