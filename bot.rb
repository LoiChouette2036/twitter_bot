require 'dotenv/load' # Pour charger les variables d'environnement
require 'x'
require 'openai'
require 'json'
require 'rufus-scheduler'
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

# Scheduler pour lancer à 10h heure française
scheduler = Rufus::Scheduler.new

# Tâche programmée à 10h heure française (UTC+1)
scheduler.cron '0 9 * * *' do
  begin
    # Obtenez la date actuelle et formatez-la
    current_date = Time.now.getlocal('+01:00').strftime("%d/%m/%Y")
    puts "Date actuelle générée : #{current_date}"

    # Génération du contenu principal
    client = OpenAI::Client.new
    loop do
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

      @content = chatgpt_response["choices"][0]["message"]["content"]
      puts "Contenu principal : #{@content}"

      # Vérification de longueur
      if @content.length <= 2000
        break
      else
        puts "Erreur : Le contenu principal dépasse 2000 caractères. Régénération..."
      end
    end

    # Publiez le tweet principal
    main_post = x_client.post("tweets", { text: @content }.to_json)
    puts "Tweet principal publié avec succès : #{main_post}"

    # Extraire l'ID du tweet principal pour le thread
    last_tweet_id = main_post['data']['id']

    # Analyse du chiffre du jour
    chiffre_du_jour = @content.match(/Le chiffre de la journée est (\d+)/)[1].to_i

    # Liste des chiffres à comparer
    chiffres_numerologie = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22, 33]

    # Génération des réponses pour chaque chiffre
    chiffres_numerologie.each do |chiffre|
      puts "Génération de contenu pour le chiffre #{chiffre}..."

      comparaison_message = nil
      loop do
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

        comparaison_message = comparaison_response["choices"][0]["message"]["content"]

        # Vérifiez la longueur
        if comparaison_message.length <= 2000
          break
        else
          puts "Erreur : La réponse dépasse 2000 caractères. Régénération..."
        end
      end

      puts "Message généré : #{comparaison_message}"

      # Publiez la réponse en tant que réponse au dernier tweet
      response_post = x_client.post("tweets", {
        text: comparaison_message,
        reply: { in_reply_to_tweet_id: last_tweet_id }
      }.to_json)

      puts "Réponse pour le chiffre #{chiffre} publiée : #{response_post}"

      # Mettre à jour l'ID du dernier tweet pour continuer le thread
      last_tweet_id = response_post['data']['id']
    end
  rescue StandardError => e
    puts "Une erreur s'est produite : #{e.message}"
  end
end

# Gardez le script en cours d'exécution
scheduler.join
