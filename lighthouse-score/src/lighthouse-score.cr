require "json"
require "http/client"

module LighthouseScore
  extend self

  def check
    begin
      # Check if it is a deployment_status event
      if ENV["GITHUB_EVENT_NAME"]? != "deployment_status"
        puts "This is not a deployment_status event"
        return 1
      end

			# Check if there is a LIGHTHOUSE_URL env variable
      if !ENV["LIGHTHOUSE_URL"]?
        puts "LIGHTHOUSE_URL is missing."
        return 1
      end

			# Check if there is a LIGHTHOUSE_SECRET env variable
      if !ENV["LIGHTHOUSE_SECRET"]?
        puts "LIGHTHOUSE_SECRET is missing."
        return 1
      end

      # Get path of event.json
      path = ENV["GITHUB_EVENT_PATH"] ||= "/github/workflow/event.json"

      # Read file and parse the JSOn
      event = File.read path
      event = JSON.parse(event)

      # Check if the deployment status is success
      if event["deployment_status"]["state"] != "success"
        puts "This deployment was not a success"
        return 78
      end

			if event["deployment"]["payload"]["web_url"]?
        
        target = event["deployment"]["payload"]["web_url"]

        puts "Running lighthouse on #{target}..."

				url = "#{ENV["LIGHTHOUSE_URL"]}?url=#{target}&secret=#{ENV["LIGHTHOUSE_SECRET"]}"
				
				resp = HTTP::Client.post(url)
				
        if resp.success?
          baseline = [0, 0, 0, 0, 0]

          if ENV["LIGHTHOUSE_SCORES"]?
            scores = Array(Int32).from_json(ENV["LIGHTHOUSE_SCORES"])
						scores.each_with_index do |score, index|
							baseline[index] = score
            end
          end

          puts "Required scores are #{baseline}, received:"
          puts "-------------------"
					body = JSON.parse(resp.body)
					
					keys = ["performance", "accessibility", "best-practices", "seo", "pwa"]

					fails = [] of String

          keys.each_with_index do |key, index|
            case body["categories"][key]["score"]
            when 0
              score = 0
            when 1
              score = 100
            else
              score = (body["categories"][key]["score"].as_f * 100.0).to_i
            end

            puts "For #{key}, score was #{score}, required was #{baseline[index]}"

						if score < baseline[index]
							fails << "#{key}"
						end
					end
          puts "-------------------"
					if fails.size > 0 
						puts "Please review: #{fails.join(", ")}"
						return 1
          else
            puts "All scores passed!"
						return 0
					end
        else
          puts "Could not run lighthouse scan"
          return 1
        end
      else
        puts "Could not find a web url"
        return 78
      end
    rescue ex
      puts ex.message
      return 1
    end
  end
end
