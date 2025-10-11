```mermaid
graph TD
    subgraph Routes
        R1["GET /up"];
    end

    subgraph Models
        M1[ApplicationRecord];
        M2["Other Models (e.g., User, Post)"];
    end

    R1 --> C1(rails/health#show);
    C1 --> M1;
    C1 --> M2;

    style R1 fill:#f9f,stroke:#333,stroke-width:2px
    style C1 fill:#bbf,stroke:#333,stroke-width:2px
    style M1 fill:#ccf,stroke:#333,stroke-width:2px
    style M2 fill:#ccf,stroke:#333,stroke-width:2px
```

### Diagram Links:

*   **Routes:** [GET /up (app/config/routes.rb)](../config/routes.rb)
*   **Controller rails/health#show:** [app/app/controllers/application_controller.rb](../app/controllers/application_controller.rb)
*   **Model ApplicationRecord:** [app/app/models/application_record.rb](../app/models/application_record.rb)
*   **Models Folder:** [app/app/models](../app/models)
