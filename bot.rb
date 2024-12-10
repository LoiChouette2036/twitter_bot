require 'dotenv/load' # Pour charger les variables d'environnement
require 'openai'
require 'json'
require 'time'

# Définir le chemin du fichier texte dans le dossier courant
file_path = "./api_results.txt"

# Si le fichier n'existe pas, le créer
unless File.exist?(file_path)
  File.open(file_path, 'w') {} # Crée un fichier vide
end

# Configuration de l'API OpenAI
OpenAI.configure do |config|
  config.access_token = ENV.fetch("OPENAI_ACCESS_TOKEN")
end

begin
  # Obtenez la date actuelle (heure française)
  current_date = Time.now.getlocal('+01:00').strftime("%d/%m/%Y")
  puts "Date actuelle générée : #{current_date}"

  # Initialiser le client OpenAI
  client = OpenAI::Client.new

  # Génération du contenu principal
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
    puts "Une erreur s'est produite lors de l'appel à l'API ChatGPT : #{e.message}"
    raise e
  end

  main_content = chatgpt_response["choices"][0]["message"]["content"]
  puts "Contenu principal généré : #{main_content}"

  # Écrire le contenu principal dans le fichier texte
  File.open(file_path, 'a') do |file|
    file.puts("=== Numerology Log for #{current_date} ===")
    file.puts(main_content)
    file.puts("\n") # Saut de ligne après le contenu principal
  end

  # Analyse du chiffre du jour
  chiffre_du_jour = main_content.match(/Le chiffre de la journée est (\d+)/)[1].to_i

  chiffres_numerologie = [1, 2, 3, 4, 5, 6, 7, 8, 9, 11, 22, 33]
  chiffres_numerologie.each do |chiffre|
    puts "Génération de contenu pour le chiffre #{chiffre}..."

    # Appel à l'API OpenAI pour chaque chiffre
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
      puts "Une erreur s'est produite lors de l'appel à l'API ChatGPT : #{e.message}"
      raise e
    end

    comparaison_message = comparaison_response["choices"][0]["message"]["content"]
    puts "Message généré pour le chiffre #{chiffre} : #{comparaison_message}"

    # Ajouter le contenu au fichier texte
    File.open(file_path, 'a') do |file|
      file.puts("=== Reply for Number #{chiffre} ===")
      file.puts(comparaison_message)
      file.puts("\n") # Saut de ligne après chaque réponse
    end
  end

  # Fin des logs
  File.open(file_path, 'a') do |file|
    file.puts("\n--- End of Log for #{current_date} ---\n")
  end

rescue StandardError => e
  puts "Une erreur s'est produite : #{e.message}"
end
