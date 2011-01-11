class JobsController < ApplicationController
  DEFAULT_LIMIT = 100
  MAX_LIMIT = 1000
  
  # List jobs
  def index
    allow :get, :post; vary_on :accept
    jobs = OAR::Job.expanded.order("job_id DESC")
    total = jobs.count
    offset = (params[:offset] || 0).to_i
    limit = [(params[:limit] || DEFAULT_LIMIT).to_i, MAX_LIMIT].min
    jobs = jobs.offset(offset).limit(limit)
    jobs = jobs.where(:job_user => params[:user]) if params[:user]  
    jobs = jobs.where(:state => params[:state].capitalize) unless params[:state].blank?
    jobs = jobs.where(:queue_name => params[:queue]) if params[:queue]
    jobs.each{|job|
      job.links = links_for_item(job)
    }
    result = {
      "total" => total,
      "offset" => offset,
      "items" => jobs,
      "links" => links_for_collection
    }
    
    respond_to do |format|
      format.json { render :json => result }
    end
  end
  
  # Display the details of a job
  def show
    allow :get, :delete; vary_on :accept
    job = OAR::Job.expanded.find(params[:id])
    job.links = links_for_item(job)
    respond_to do |format|
      format.json { render :json => job }
    end
  end
  
  # Delete a job. Client must be authenticated and must own the job.
  # 
  # Delegates to the OAR API.
  def destroy
    ensure_authenticated!
    job = OAR::Job.find(params[:id])
    authorize!(job.user)
    
    url = uri_to(
      platform_site_path(
        params[:platform_id], 
        params[:site_id]
      )+"/internal/oarapi/jobs/#{params[:id]}.json", 
      :out
    )
    http = EM::HttpRequest.new(url).delete(
      :timeout => 5,
      :head => {
        'X-Remote-Ident' => @credentials[:cn],
        'Accept' => media_type(:json)
      }
    )
    
    continue_if!(http, :is => [200,202,204,404])
    
    if http.response_header.status == 404
      raise NotFound, "Cannot find job##{params[:id]} on the OAR server"
    else
      response.headers['X-Oar-Info'] = (
        JSON.parse(http.response)['oardel_output'] || ""
      ).split("\n").join(" ") rescue "-"
      
      location_uri = uri_to(
        platform_site_job_path(
          params[:platform_id], params[:site_id], params[:id]
        ), 
        :in, :absolute
      )
      
      render  :text => "", 
              :head => :ok, 
              :location => location_uri, 
              :status => 202
    end
  end
  
  # Create a new Job. Client must be authenticated.
  # 
  # Delegates the request to the OAR API.
  def create
    ensure_authenticated!
    
    job = Job.new(params)
    Rails.logger.info "Received job = #{job.inspect}"
    raise BadRequest, "The job you are trying to submit is not valid: #{job.errors.join("; ")}" unless job.valid?
    job_to_send = job.to_hash(:destination => "oar-2.4-submission")
    Rails.logger.info "Submitting #{job_to_send.inspect}"
    
    url = uri_to(
      platform_site_path(params[:platform_id], params[:site_id])+"/internal/oarapi/jobs.json", :out)
    http = EM::HttpRequest.new(url).post(
      :timeout => 20,
      :body => job_to_send.to_json,
      :head => {
        'X-Remote-Ident' => @credentials[:cn],
        'Content-Type' => media_type(:json),
        'Accept' => media_type(:json)
      }
    )
    continue_if!(http, :is => [201,202])
    
    job_uid = JSON.parse(http.response)['id']
    location_uri = uri_to(
      platform_site_job_path(params[:platform_id], params[:site_id], job_uid), 
      :in, :absolute
    )
    render  :text => "", 
            :head => :ok, 
            :location => location_uri, 
            :status => 201
  end
  
  protected
  def collection_path
    platform_site_jobs_path(params[:platform_id], params[:site_id])
  end
  
  def parent_path
    platform_site_path(params[:platform_id], params[:site_id])
  end
  
  def resource_path(id)
    File.join(collection_path, id.to_s)
  end
  
  def links_for_item(item)
    [
      {
        "rel" => "self",
        "href" => uri_to(resource_path(item.uid)),
        "type" => media_type(:json)
      },
      {
        "rel" => "parent",
        "href" => uri_to(parent_path),
        "type" => media_type(:json)
      }      
    ]
  end
  
  def links_for_collection
    [
      {
        "rel" => "self",
        "href" => uri_to(collection_path),
        "type" => media_type(:json_collection)
      },
      {
        "rel" => "parent",
        "href" => uri_to(parent_path),
        "type" => media_type(:json)
      }      
    ]
  end
end