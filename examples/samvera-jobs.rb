require_relative "../lib/job_grapher"

JobGrapher.plantuml_for(
  dirs: [
    "~/git/hyrax",
    "~/git/bulkrax",
    "~/git/hyku",
    "~/git/newspaper_works/"
  ],
  # filter: ->(job) do
  #   job.include?("Permission") || job.include?("Ingest")
  # end
)