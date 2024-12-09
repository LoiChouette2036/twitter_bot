require 'dotenv/load' # To load environment variables from .env
require 'x'
require 'openai'
require 'json'
require 'rufus-scheduler'

x_credentials = {
  api_key:              ENV['X_API_KEY'],
  api_key_secret:       ENV['X_API_KEY_SECRET'],
  access_token:         ENV['X_ACCESS_TOKEN'],
  access_token_secret:  ENV['X_ACCESS_TOKEN_SECRET'],
}

puts x_credentials.inspect

# Initialize an X API client with your OAuth credentials
x_client = X::Client.new(**x_credentials)

# Get data about yourself
response = x_client.get("users/me")
puts response

# Initailize OpenAI
OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
end

begin
  # Generate the main content from OpenAI
  client = OpenAI::Client.new
  chatgpt_response = client.chat(parameters: {
    model: "gpt-4o-mini",
    messages: [{
      role: "user",
      content: "Génère un message de 280 caractères maximum de numérologie pour la date actuelle.  
        Stp, respecte **280 caractères** et ne dépasse surtout pas cette limite.  
        Suivre cette structure :  
        1. 'Date du jour : [JJ/MM/AAAA] => [calcul complet en une ligne, ex. 2+8+1+0+2+0+2+3=18 => 1+8=9]'.  
        2. 'Le chiffre de la journée est [chiffre calculé]'.  
        3. Signification détaillée du chiffre en une phrase fluide et concise.  
        Formate le texte pour qu'il soit fluide, clair et impactant."
    }]
  })

  @content = chatgpt_response["choices"][0]["message"]["content"]
  puts "Contenu principal : #{@content}"

  # Vérification de la longueur
  if @content.length > 280
    puts "Erreur : Le contenu principal dépasse 280 caractères."
    exit
  end

  # Post the main tweet
  main_post = x_client.post("tweets", { text: @content }.to_json)
  puts "Tweet principal publié avec succès : #{main_post}"

  # Extract tweet ID for threading
  main_tweet_id = main_post['data']['id']

  # Parse the chiffre du jour
  chiffre_du_jour = @content.match(/Le chiffre de la journée est (\d+)/)[1].to_i

  # Chiffres de la numérologie à comparer
  chiffres_numerologie = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22, 33]

  # Generate thread responses
  chiffres_numerologie.each do |chiffre|
    comparaison_response = client.chat(parameters: {
      model: "gpt-4o-mini",
      messages: [{
        role: "user",
        content: "Compare le chiffre #{chiffre_du_jour} (chiffre du jour) avec le chiffre #{chiffre}.  
          Fournis une analyse détaillée mais concise (280 caractères maximum) sur leurs énergies respectives et comment elles peuvent interagir.  
          Sois clair et impactant."
      }]
    })

    comparaison_message = comparaison_response["choices"][0]["message"]["content"]

    # Vérification de la longueur
    if comparaison_message.length > 280
      comparaison_message = comparaison_message[0..276] + "..."
    end

    # Post each comparison as a reply in the thread
    response_post = x_client.post("tweets", {
      text: comparaison_message,
      reply: { in_reply_to_tweet_id: main_tweet_id }
    }.to_json)

    puts "Réponse pour le chiffre #{chiffre} publiée : #{response_post}"
  end
rescue StandardError => e
  puts "Une erreur s'est produite : #{e.message}"
end
