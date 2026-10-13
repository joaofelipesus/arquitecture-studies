json.id book.id
json.title book.title
json.description book.description
json.release_date book.release_date
json.total_pages book.total_pages
json.created_at book.created_at
json.updated_at book.updated_at

json.authors book.authors do |author|
  json.id author.id
  json.name author.name
  json.biography author.biography
  json.created_at author.created_at
  json.updated_at author.updated_at
end

json.subjects book.subjects do |subject|
  json.id subject.id
  json.name subject.name
  json.created_at subject.created_at
  json.updated_at subject.updated_at
end
