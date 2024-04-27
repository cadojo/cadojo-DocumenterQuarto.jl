module QuartoDocumenter

using Quarto
using Markdown
using InteractiveUtils

function autodoc(mod::Module, symbols::Symbol...; delimiter=md"{{< pagebreak >}}")
    svec = isempty(symbols) ? Base.names(mod) : symbols
    return Markdown.MD(map(name -> Markdown.MD(doc(getproperty(mod, name)), delimiter), svec)...)
end

macro autodoc(lvalues...)
    return quote
        autodoc(@__MODULE__, $(lvalues...))
    end
end

macro autodocs(lvalues)
    return quote
        autodoc(@__MODULE__, $(lvalues)...)
    end
end

level(::Markdown.Header{T}) where {T} = T

function process_headers(markdown)
    for (index, item) in enumerate(markdown.content)
        if item isa Markdown.Header
            newlevel = min(level(item) + 3, 6)
            if item.text isa AbstractVector
                @info "Appending to item.text"
                push!(item.text, " {.unnumbered} ")
            elseif item.text isa AbstractString
                item.text *= " {.unnumbered} "
            end
            markdown.content[index] = Markdown.Header{newlevel}(item.text)
        elseif :content in propertynames(item)
            markdown.content[index] = process_headers(item)
        end
    end
    return markdown
end

function process_admonitions(markdown)
    for (index, item) in enumerate(markdown.content)
        if item isa Markdown.Admonition
            markdown.content[index] = Markdown.MD(
                Markdown.parse(""":::{.callout-$(item.category) title="$(item.title)"}"""),
                item.content...,
                md":::",
            )
        elseif :content in propertynames(item)
            markdown.content[index] = process_admonitions(item)
        end
    end
    return markdown
end

function process_xref(markdown)
    for (index, item) in enumerate(markdown.content)
        if item isa Markdown.Link
            markdown.content[index] = Markdown.MD(item.text)
        elseif :content in propertynames(item)
            markdown.content[index] = process_xref(item)
        end
    end
    return markdown
end

function process(markdown)
    return (
        markdown
        |> process_headers
        |> process_admonitions
        |> process_xref
    )
end

function doc(mod::Module, sym::Symbol)
    parent = which(mod, sym)
    docmkd = copy(Base.Docs.doc(Docs.Binding(parent, sym)))
    return doc(docmkd)
end

function doc(any::Any)
    @info Base.Docs.doc(any) |> typeof
    docmkd = process(
        copy(Base.Docs.doc(any))
    )

    return Markdown.MD(
        Markdown.parse(""":::{.callout appearance="simple"}"""),
        docmkd,
        md":::"
    )
end

function doc(mod::Module)
    docmkd = process(
        copy(Base.Docs.doc(mod))
    )

    return Markdown.MD(
        docmkd
    )
end

end # module QuartoDocumenter