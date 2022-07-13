class AltStore
  mappings = Searchkick.unified_mappings(
    :alt_store,
    {
      properties: {
        nested_field: {
          type: 'nested',
          properties: {
            name: {type: 'text'}
          }
        },
        employees: {
          type: 'nested',
          properties: {
            reviews: {
              type: 'nested',
              properties: {
                comments: {
                  type: 'nested'
                }
              }
            },
            time_cards: {
              type: 'nested'
            }
          }
        }
      }
    }
  )

  searchkick \
    routing: true,
    merge_mappings: true,
    mappings: mappings

  def search_document_id
    id
  end

  def search_routing
    name
  end

  def search_data
    data = {employees: []}
    employees.map{|e| data[:employees] << {
        name: e.try(:name),
        age: e.try(:age),
        reviews: e.try(:reviews).collect{ |r|
          {
            name: r.try(:name),
            stars: r.try(:stars),
            comments: r.comments.collect{ |c|
              {
                status: c.try(:status),
                message: c.try(:message)
              }
            }
          }
        },
        time_cards: e.try(:time_cards).collect{ |tc|
          {
            hours: tc.try(:hours)
          }
        }
      }
    }
    data[:nested_field] = nested_json&.dig('nested_field')
    serializable_hash.except("id", "_id").merge(
      data
    )
  end
end
