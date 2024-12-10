require 'dotenv/load' # Pour charger les variables d'environnement
require 'x'
require 'openai'
require 'json'
require 'time'

# Initialisation des credentials pour X API
x_credentials = {
  api_key:              ENV['X_API_KEY'],
  api_key_secret:       ENV['X_API_KEY_SECRET'],
  access_token:         ENV['X_ACCESS_TOKEN'],
  access_token_secret:  ENV['X_ACCESS_TOKEN_SECRET'],
}

puts x_credentials.inspect

# Initialisation du client X API
x_client = X::Client.new(**x_credentials)

# Configuration de l'API OpenAI
OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
end

begin
  # Obtenez la date actuelle (heure française)
  current_date = Time.now.getlocal('+01:00').strftime("%d/%m/%Y")
  puts "Date actuelle générée : #{current_date}"

  # Génération du contenu principal
  client = OpenAI::Client.new

  begin
    chatgpt_response = client.chat(parameters: {
      model: "gpt-4o-mini",
      messages: [{
        role: "user",
        content: "Génère un message détaillé pour la numérologie du jour en **2000 caractères maximum**.  
        La date du jour est #{current_date}. Inclure :  
        1. 'Date du jour : #{current_date} => [calcul complet en une ligne, ex. 2+8+1+0+2+0+2+3=18 => 1+8=9]'.  
        2. 'Le chiffre de la journée est [chiffre calculé]'.  
        3. Une analyse approfondie du chiffre, expliquant ses impacts émotionnels, professionnels et spirituels.  
        4. Des conseils pratiques et spirituels basés sur ce chiffre."
      }]
    })
  rescue StandardError => e
    # Identifiez si le problème vient de l'API ChatGPT
    puts "Une erreur s'est produite lors de l'appel à l'API ChatGPT : #{e.message}" if e.message.include?("Too Many Requests")
    raise e
  end

  @content = chatgpt_response["choices"][0]["message"]["content"]
  puts "Contenu principal : #{@content}"

  # Publiez le tweet principal
  begin
    main_post = x_client.post("tweets", { text: @content }.to_json)
    # Ajoutez une vérification des limites d'utilisation
    puts "Tweet principal publié avec succès. Vérifiez vos limites actuelles :"
    puts "Limites restantes (Twitter/X API): #{main_post.headers['x-rate-limit-remaining']}"
    puts "Réinitialisation prévue à : #{Time.at(main_post.headers['x-rate-limit-reset'].to_i)}"
  rescue StandardError => e
    # Identifiez si le problème vient de l'API Twitter/X
    puts "Une erreur s'est produite lors de l'appel à l'API Twitter/X : #{e.message}" if e.message.include?("Too Many Requests")
    raise e
  end

  # Attendez 60 secondes après la création du tweet principal pour éviter les limites
  puts "Attente de 60 secondes avant de générer les réponses..."
  sleep(60)

  # Extraire l'ID du tweet principal pour le thread
  last_tweet_id = main_post['data']['id']

  # Analyse du chiffre du jour
  chiffre_du_jour = @content.match(/Le chiffre de la journée est (\d+)/)[1].to_i

  # Liste des chiffres à comparer
  chiffres_numerologie = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22, 33]

  # Génération des réponses pour chaque chiffre
  chiffres_numerologie.each do |chiffre|
    puts "Génération de contenu pour le chiffre #{chiffre}..."
  
    begin
      comparaison_response = client.chat(parameters: {
        model: "gpt-4o-mini",
        messages: [{
          role: "user",
          content: "Pour le numéro #{chiffre} : avec le chiffre du jour #{chiffre_du_jour}, en numérologie, fournissez une analyse détaillée jusqu'à **2000 caractères**.  
            Inclure :  
            1. Les qualités principales du chiffre #{chiffre}.  
            2. L’effet du chiffre #{chiffre_du_jour} sur ces qualités.  
            3. Des suggestions pratiques ou spirituelles basées sur cette combinaison.  
            Structurez la réponse pour qu’elle soit claire et engageante."
        }]
      })
    rescue StandardError => e
      # Identifiez si le problème vient de l'API ChatGPT
      puts "Une erreur s'est produite lors de l'appel à l'API ChatGPT : #{e.message}" if e.message.include?("Too Many Requests")
      raise e
    end
  
    comparaison_message = comparaison_response["choices"][0]["message"]["content"]
    puts "Message généré : #{comparaison_message}"
  
    # Publiez la réponse en tant que réponse au dernier tweet
    begin
      response_post = x_client.post("tweets", {
        text: comparaison_message,
        reply: { in_reply_to_tweet_id: last_tweet_id }
      }.to_json)
      # Ajoutez une vérification des limites d'utilisation
      puts "Réponse publiée avec succès. Limites restantes : #{response_post.headers['x-rate-limit-remaining']}"
    rescue StandardError => e
      # Identifiez si le problème vient de l'API Twitter/X
      puts "Une erreur s'est produite lors de l'appel à l'API Twitter/X : #{e.message}" if e.message.include?("Too Many Requests")
      raise e
    end
  
    # Mettre à jour l'ID du dernier tweet pour continuer le thread
    last_tweet_id = response_post['data']['id']
  
    # Ajoutez une pause de 60 secondes entre les réponses
    puts "Attente de 60 secondes avant la prochaine réponse..."
    sleep(60)
  end
rescue StandardError => e
  puts "Une erreur s'est produite : #{e.message}"
end
