module Fog
  module Storage
    class Google
      class Real

        def tag(name, value)
          "<#{name}>#{value}</#{name}>"
        end

        def scope_tag(scope)
          if %w(AllUsers AllAuthenticatedUsers).include?(scope['type'])
            "<Scope type='#{scope['type']}'/>"
          else
            "<Scope type='#{scope['type']}'>" + 
              scope.to_a.select {|pair| pair[0] != 'type'}.map { |pair| tag(pair[0], pair[1]) }.join("\n") +
            "</Scope>"
          end
        end

        def entries_list(access_control_list)
          access_control_list.map do |entry|
            tag('Entry', scope_tag(entry['Scope']) + tag('Permission', entry['Permission']))
          end.join("\n")
        end

        # Change access control list for an Google Storage bucket
        #
        # ==== Parameters
        # * bucket_name<~String> - name of bucket to modify
        # * acl<~Hash>:
        #   * Owner<~Hash>:
        #     * ID<~String>: id of owner
        #   * AccessControlList<~Array>:
        #     * scope<~Hash>:
        #         * 'type'<~String> - 'UserById'
        #         * 'ID'<~String> - Id of grantee
        #       or
        #         * 'type'<~String> - 'UserByEmail'
        #         * 'EmailAddress'<~String> - Email address of grantee
        #       or
        #         * 'type'<~String> - type of user to grant permission to
        #     * Permission<~String> - Permission, in [FULL_CONTROL, WRITE, WRITE_ACP, READ, READ_ACP]
        def put_bucket_acl(bucket_name, acl)
          # acl = new_acl.dup

          data = <<-DATA
<AccessControlList>
  <Owner>
    #{tag('ID', acl['Owner']['ID'])}
  </Owner>
  <Entries>
    #{entries_list(acl['AccessControlList'].dup)}
  </Entries>
</AccessControlList>
DATA

puts "REQUEST!!"
puts data

          request({
            :body     => data,
            :expects  => 200,
            :headers  => {},
            :host     => "#{bucket_name}.#{@host}",
            :method   => 'PUT',
            :query    => {'acl' => nil}
          })
        end

      end
    end
  end
end
